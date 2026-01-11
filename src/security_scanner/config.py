from pydantic_settings import BaseSettings
from typing import Optional
import os

class Settings(BaseSettings):
    app_name: str = "Pan-Sec"
    version: str = "2.0.0"
    
    # Paths
    install_dir: str = os.getcwd()
    reports_dir: str = os.path.join(os.getcwd(), "reports")
    logs_dir: str = os.path.join(os.getcwd(), "logs")
    
    # Email
    email_recipient: str = "root@localhost"
    email_from_name: str = "Pan-Sec Scanner"
    
    # Scan Settings
    network_timeout: int = 60
    port_scan_timeout: int = 30
    nmap_timing: str = "-T4"
    
    # Risk Calculation Weights
    weight_critical: int = 10
    weight_high: int = 5
    weight_medium: int = 2
    weight_low: int = 1
    
    # Thresholds
    threshold_critical: int = 50
    threshold_high: int = 30
    threshold_medium: int = 15

    class Config:
        env_prefix = "PAN_SEC_"

settings = Settings()
