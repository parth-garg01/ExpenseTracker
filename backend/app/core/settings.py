from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = Field(
        default='postgresql+psycopg://postgres:postgres@localhost:5432/expense_tracker',
        alias='API_KEY_01_DATABASE_URL',
    )
    jwt_secret: str = Field(default='change-me', alias='API_KEY_02_JWT_SECRET')

    model_config = SettingsConfigDict(env_file='.env', env_file_encoding='utf-8')


settings = Settings()
