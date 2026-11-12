from fastapi import FastAPI
from record_event import record_event

app = FastAPI()

@app.post("/record_event")
def record_event_endpoint(microcontroller_mac_address: str, event_type: str):
    return record_event(microcontroller_mac_address, event_type)