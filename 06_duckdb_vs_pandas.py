import duckdb
import pandas as pd
import time
import psutil
import os

FILE_PATH = "data/yellow_tripdata_2023-01.parquet"

def get_memory_usage():
    """Mevcut sürecin RAM kullanımını MB cinsinden döndürür."""
    process = psutil.Process(os.getpid())
    return process.memory_info().rss / (1024 * 1024)

# DuckDB için SQL sorgularımız
queries = [
    "SELECT COUNT(*) FROM '{}'",
    "SELECT passenger_count, COUNT(*) FROM '{}' GROUP BY passenger_count",
    "SELECT VendorID, AVG(fare_amount) FROM '{}' GROUP BY VendorID",
    "SELECT payment_type, SUM(total_amount) FROM '{}' GROUP BY payment_type",
    "SELECT MAX(trip_distance) FROM '{}'",
    "SELECT MIN(tolls_amount), MAX(tolls_amount) FROM '{}'",
    "SELECT passenger_count, AVG(tip_amount) FROM '{}' GROUP BY passenger_count",
    "SELECT RatecodeID, COUNT(*) FROM '{}' GROUP BY RatecodeID",
    "SELECT VendorID, SUM(extra) FROM '{}' GROUP BY VendorID",
    "SELECT AVG(fare_amount), MAX(fare_amount) FROM '{}'"
]

print("🚀 DUCKDB TESTİ BAŞLIYOR (Sunucusuz, Diskten Okuma)...")
start_mem_duckdb = get_memory_usage()
start_time_duckdb = time.time()

# 10 Sorguyu çalıştır
for q in queries:
    duckdb.execute(q.format(FILE_PATH)).fetchall()

duckdb_time = time.time() - start_time_duckdb
duckdb_mem = get_memory_usage() - start_mem_duckdb

print(f"✅ DuckDB Süre: {duckdb_time:.3f} saniye")
print(f"✅ DuckDB Bellek Tüketimi: {max(duckdb_mem, 0):.2f} MB\n")


print("🐢 PANDAS TESTİ BAŞLIYOR (Veriyi RAM'e Yükleme)...")
start_mem_pandas = get_memory_usage()
start_time_pandas = time.time()

# Pandas ile aynı işlemleri yap (Önce tüm dosyayı RAM'e almak zorundadır)
df = pd.read_parquet(FILE_PATH)

_ = len(df)
_ = df.groupby('passenger_count').size()
_ = df.groupby('VendorID')['fare_amount'].mean()
_ = df.groupby('payment_type')['total_amount'].sum()
_ = df['trip_distance'].max()
_ = (df['tolls_amount'].min(), df['tolls_amount'].max())
_ = df.groupby('passenger_count')['tip_amount'].mean()
_ = df.groupby('RatecodeID').size()
_ = df.groupby('VendorID')['extra'].sum()
_ = (df['fare_amount'].mean(), df['fare_amount'].max())

pandas_time = time.time() - start_time_pandas
pandas_mem = get_memory_usage() - start_mem_pandas

print(f"✅ Pandas Süre: {pandas_time:.3f} saniye")
print(f"✅ Pandas Bellek Tüketimi: {pandas_mem:.2f} MB\n")