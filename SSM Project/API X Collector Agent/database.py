from sqlalchemy import create_engine
from databases import Database
from models import metadata

DATABASE_URL = 'postgresql://postgres:Vongola10@localhost:5432/SSM'

database = Database(DATABASE_URL)
engine = create_engine(DATABASE_URL)

metadata.create_all(engine)