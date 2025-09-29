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

# --- Leer archivo con diagnóstico ---
# Primero leemos algunas líneas para ver el formato
print("Leyendo archivo para diagnóstico...")

# Intentar leer desde la fila 10 (header en A11)
try:
    df = pd.read_csv(input_file, sep=",", skiprows=10)
    print("✅ Lectura exitosa con sep=','")
except Exception as e:
    print(f"❌ Error con sep=',': {e}")
    # Intentar con tabulaciones
    try:
        df = pd.read_csv(input_file, sep="\t", skiprows=10)
        print("✅ Lectura exitosa con sep='\\t'")
    except Exception as e2:
        print(f"❌ Error con sep='\\t': {e2}")
        # Intentar auto-detectar
        df = pd.read_csv(input_file, skiprows=10)
        print("✅ Lectura con separador auto-detectado")

# Verificar qué columnas tenemos
print("Columnas disponibles:", df.columns.tolist())
print("Forma del DataFrame:", df.shape)
print("Primeras filas:")
print(df.head(3))

# Limpiar nombres de columnas (quitar espacios)
df.columns = df.columns.str.strip()

# Renombrar la primera columna a "Datetime"
first_col = df.columns[0]
print(f"Primera columna: '{first_col}'")
df.rename(columns={first_col: "Datetime"}, inplace=True)

# Convertir fecha con manejo de errores
print("Convirtiendo fechas...")
try:
    # Intentar formato DD/MM/YYYY
    df["Datetime"] = pd.to_datetime(df["Datetime"], format="%d/%m/%Y %H:%M:%S")
    print("✅ Fechas convertidas con formato DD/MM/YYYY")
except Exception as e:
    print(f"❌ Error con formato DD/MM/YYYY: {e}")
    try:
        # Intentar auto-detectar
        df["Datetime"] = pd.to_datetime(df["Datetime"], dayfirst=True)
        print("✅ Fechas convertidas con auto-detección")
    except Exception as e2:
        print(f"❌ Error con auto-detección: {e2}")
        # Mostrar algunos valores para diagnóstico
        print("Valores de fecha problemáticos:")
        print(df["Datetime"].head(10).tolist())
        raise

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
