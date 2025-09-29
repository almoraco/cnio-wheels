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

# --- Leer archivo, saltando hasta la fila 10 (índice 10) para que los headers estén en A11 ---
df = pd.read_csv(input_file, sep=",", skiprows=10)  # Cambiado separador a coma

# Verificar qué columnas tenemos
print("Columnas disponibles:", df.columns.tolist())
print("Primeras filas:")
print(df.head())

# Renombrar la primera columna (que debería ser "Bin") a "Datetime"
# Usar el índice por si el nombre tiene espacios o caracteres raros
df.rename(columns={df.columns[0]: "Datetime"}, inplace=True)

# Convertir fecha
df["Datetime"] = pd.to_datetime(df["Datetime"], dayfirst=True)

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

# Etiquetar día/noche
def label_period(dt):
    return "Day" if 7 <= dt.hour < 19 else "Night"

df_long["Period"] = df_long["Datetime"].apply(label_period)

# Guardar combinado
combined_file = proc_dir / "revolutions_hourly.csv"
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
    plt.title(f"Actividad por hora - {mouse}")
    plt.xlabel("Hora")
    plt.ylabel("Revoluciones")
    plt.grid(True, linestyle="--", alpha=0.5)
    plt.legend()
    plt.tight_layout()

    plot_file = plot_dir / f"{mouse}.png"
    plt.savefig(plot_file)
    plt.close()

    print(f"  ➜ Guardado {mouse_file} y {plot_file}")
