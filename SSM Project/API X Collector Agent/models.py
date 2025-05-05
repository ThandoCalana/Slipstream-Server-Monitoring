from sqlalchemy import Column, Integer, TIMESTAMP, Float, MetaData, Table

metadata = MetaData()

system_metrics = Table(
    "system_metrics",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("mem_free_GB", Float),
    Column("mem_used_GB", Float),
    Column("mem_total_GB", Float),
    Column("cpu_percentage", Float),
    Column("disk_used_GB", Float),
    Column("disk_total_GB", Float),
    Column("disk_free_GB", Float),
    Column("rec_time", TIMESTAMP)
)
