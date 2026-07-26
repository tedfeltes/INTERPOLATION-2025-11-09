"""Run with: python -m app  OR  uvicorn app.main:app --reload"""

import uvicorn


def main() -> None:
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=False)


if __name__ == "__main__":
    main()
