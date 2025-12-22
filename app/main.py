from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "Hello, Multi-Arch Docker!"}

@app.get("/arch")
def get_arch():
    import platform
    return {"architecture": platform.machine()}
