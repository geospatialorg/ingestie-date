import pandas as pd

input_file = "/storage/volumes/geoserver-1-storage/tmp/caroiaj_ancpi_40km.csv"
output_file = "/storage/volumes/geoserver-1-storage/tmp/caroiaj_ancpi_40km.wkt"

def create_wkt_polygon(row):
    """
    Creează un poligon în format WKT pe baza coordonatelor.
    """
    xmin, xmax, ymin, ymax = row['xmin'], row['xmax'], row['ymin'], row['ymax']
    return f"POLYGON(({xmin} {ymin}, {xmax} {ymin}, {xmax} {ymax}, {xmin} {ymax}, {xmin} {ymin}))"

def process_csv(input_file, output_file):
    """
    Citește un fișier CSV, generează coloana WKT și salvează un fișier nou.
    """
    try:
        # Citește fișierul CSV
        data = pd.read_csv(input_file)

        # Adaugă coloana WKT
        data['WKT'] = data.apply(create_wkt_polygon, axis=1)

        # Salvează fișierul procesat
        data.to_csv(output_file, index=False)
        print(f"Fișierul procesat a fost salvat: {output_file}")
    except Exception as e:
        print(f"Eroare la procesarea fișierului {input_file}: {e}")

process_csv(input_file, output_file)
