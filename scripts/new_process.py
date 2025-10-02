import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path

# --- Parámetros ---
input_file = Path("data/raw/revolutions.csv")
output_dir = Path("output")
proc_dir = output_dir / "processed"
plot_dir = output_dir / "plots"

proc_dir.mkdir(parents=True, exist_ok=True)
plot_dir.mkdir(parents=True, exist_ok=True)

# --- Leer archivo CSV limpio ---
print("Leyendo archivo CSV...")

# El archivo usa tabulaciones como separador
df = pd.read_csv(input_file, sep="\t")  # Sin skiprows, headers en primera fila
print("✅ Archivo leído correctamente")

# Verificar estructura
print("Columnas disponibles:", df.columns.tolist())
print("Forma del DataFrame:", df.shape)
print("Primeras filas:")
print(df.head(3))

# Renombrar la primera columna a "Datetime" 
df.rename(columns={"Time": "Datetime"}, inplace=True)

# Convertir fecha
print("Convirtiendo fechas...")
df["Datetime"] = pd.to_datetime(df["Datetime"], format="%d/%m/%Y %H:%M:%S")
print("✅ Fechas convertidas correctamente")

# Pasar a formato largo
df_long = df.melt(id_vars="Datetime", var_name="MouseID", value_name="Revolutions")

# Ordenar
df_long = df_long.sort_values(["MouseID", "Datetime"])

# Reagrupar a intervalos de 1h exacta
df_long = (
    df_long
    .set_index("Datetime")
    .groupby("MouseID")
    .resample("1H")["Revolutions"]
    .sum()
    .reset_index()
)

# Calcular metros
df_long["Meters"] = df_long["Revolutions"] * 0.060198

# Guardar combinado
combined_file = proc_dir / "activity_hourly.csv"
df_long.to_csv(combined_file, index=False)
print(f"✅ Guardado combinado en {combined_file}")

# Guardar por ratón + gráficas
for mouse, group in df_long.groupby("MouseID"):
    # CSV individual
    mouse_file = proc_dir / f"{mouse}.csv"
    group.to_csv(mouse_file, index=False)

    # Gráfica individual
    plt.figure(figsize=(10, 4))
    plt.plot(group["Datetime"], group["Revolutions"], marker="o", label=mouse)
    plt.title(f"Voluntary activity of mouse  {mouse}")
    plt.xlabel("Date (and hour)")
    plt.ylabel("Revolutions (no.)")
    plt.grid(True, linestyle="--", alpha=0.5)
    plt.legend()
    plt.tight_layout()

    plot_file = plot_dir / f"{mouse}.png"
    plt.savefig(plot_file)
    plt.close()

    print(f"  ➜ Guardado {mouse_file} y {plot_file}")
