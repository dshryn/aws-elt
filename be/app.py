from pathlib import Path

import joblib
import pandas as pd

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel, Field


# ============================================================
# PATHS
# ============================================================

# app.py is located at:
#
# CloudComp/
# └── be/
#     └── app.py
#
# Therefore:
# parent      -> be/
# parent.parent -> CloudComp/

BASE_DIR = Path(__file__).resolve().parent.parent

MODEL_PATH = (
    BASE_DIR
    / "model"
    / "flight_delay_xgboost_model.joblib"
)

FRONTEND_DIR = BASE_DIR / "fe"

TEMPLATES_DIR = FRONTEND_DIR / "templates"

STATIC_DIR = FRONTEND_DIR / "static"


# ============================================================
# BASIC FILE VALIDATION
# ============================================================

if not MODEL_PATH.exists():
    raise FileNotFoundError(
        f"Model file not found:\n{MODEL_PATH}"
    )

if not TEMPLATES_DIR.exists():
    raise FileNotFoundError(
        f"Templates directory not found:\n{TEMPLATES_DIR}"
    )

if not STATIC_DIR.exists():
    raise FileNotFoundError(
        f"Static directory not found:\n{STATIC_DIR}"
    )


# ============================================================
# FASTAPI APPLICATION
# ============================================================

app = FastAPI(
    title="Flight Delay Predictor",
    description=(
        "Flight delay prediction using the finalized "
        "XGBoost model."
    ),
    version="1.0.0"
)


# ============================================================
# STATIC FILES
# ============================================================

app.mount(
    "/static",
    StaticFiles(directory=str(STATIC_DIR)),
    name="static"
)


# ============================================================
# HTML TEMPLATES
# ============================================================

templates = Jinja2Templates(
    directory=str(TEMPLATES_DIR)
)


# ============================================================
# LOAD FINALIZED MODEL
# ============================================================

try:

    model = joblib.load(MODEL_PATH)

except Exception as e:

    raise RuntimeError(
        f"Failed to load model from:\n"
        f"{MODEL_PATH}\n\n"
        f"Error: {e}"
    ) from e


print("=" * 60)
print("FLIGHT DELAY PREDICTION API")
print("=" * 60)
print(f"Model path : {MODEL_PATH}")
print(f"Model type : {type(model).__name__}")
print("=" * 60)


# ============================================================
# FINAL MODEL FEATURES
# ============================================================

# These are the EXACT features used by the finalized
# training notebook.

MODEL_FEATURES = [
    "AIRLINE",
    "MONTH_CATEGORY",
    "PREV_ARRIVAL_DELAY_RATE",
    "PREV_AVG_ARR_DELAY",
    "PREV_TOTAL_FLIGHTS",
    "PREV_CANCELLATION_RATE"
]


# ============================================================
# REQUEST MODEL
# ============================================================

class PredictionRequest(BaseModel):

    AIRLINE: str = Field(
        ...,
        min_length=1,
        description="Airline name"
    )

    MONTH: int = Field(
        ...,
        ge=1,
        le=12,
        description="Prediction month, 1-12"
    )

    PREV_ARRIVAL_DELAY_RATE: float = Field(
        ...,
        ge=0,
        le=1,
        description="Previous month's arrival delay rate"
    )

    PREV_AVG_ARR_DELAY: float = Field(
        ...,
        description="Previous month's average arrival delay"
    )

    PREV_TOTAL_FLIGHTS: int = Field(
        ...,
        ge=0,
        description="Previous month's total flights"
    )

    PREV_CANCELLATION_RATE: float = Field(
        ...,
        ge=0,
        le=1,
        description="Previous month's cancellation rate"
    )


# ============================================================
# FRONTEND ROUTE
# ============================================================

@app.get(
    "/",
    response_class=HTMLResponse
)
async def home(request: Request):

    return templates.TemplateResponse(
        request=request,
        name="index.html",
        context={}
    )


# ============================================================
# HEALTH CHECK
# ============================================================

@app.get("/health")
async def health_check():

    return {
        "status": "ok",
        "model_loaded": model is not None
    }


# ============================================================
# MODEL FEATURE CHECK
# ============================================================

def validate_model_features():

    """
    Verify that the saved model exposes the same original
    feature names used during training.

    The finalized notebook trains the pipeline using:

        AIRLINE
        MONTH_CATEGORY
        PREV_ARRIVAL_DELAY_RATE
        PREV_AVG_ARR_DELAY
        PREV_TOTAL_FLIGHTS
        PREV_CANCELLATION_RATE
    """

    if not hasattr(model, "feature_names_in_"):
        return

    actual_features = list(model.feature_names_in_)

    if actual_features != MODEL_FEATURES:

        raise RuntimeError(
            "Saved model feature mismatch.\n\n"
            f"Expected:\n{MODEL_FEATURES}\n\n"
            f"Found:\n{actual_features}"
        )


# Perform the check once when the application starts.
validate_model_features()


# ============================================================
# PREDICTION ENDPOINT
# ============================================================

@app.post("/predict")
async def predict(data: PredictionRequest):

    try:

        # ----------------------------------------------------
        # Convert MONTH -> MONTH_CATEGORY
        # ----------------------------------------------------
        #
        # The frontend sends:
        #
        #     MONTH = 7
        #
        # But the finalized ML notebook creates:
        #
        #     MONTH_CATEGORY = "7"
        #
        # This is therefore the exact representation required
        # by the saved preprocessing pipeline.
        # ----------------------------------------------------

        month_category = str(data.MONTH)


        # ----------------------------------------------------
        # Construct EXACT model input
        # ----------------------------------------------------

        input_data = {
            "AIRLINE": data.AIRLINE,
            "MONTH_CATEGORY": month_category,
            "PREV_ARRIVAL_DELAY_RATE":
                data.PREV_ARRIVAL_DELAY_RATE,
            "PREV_AVG_ARR_DELAY":
                data.PREV_AVG_ARR_DELAY,
            "PREV_TOTAL_FLIGHTS":
                data.PREV_TOTAL_FLIGHTS,
            "PREV_CANCELLATION_RATE":
                data.PREV_CANCELLATION_RATE
        }


        # ----------------------------------------------------
        # Create DataFrame
        # ----------------------------------------------------

        input_df = pd.DataFrame(
            [input_data],
            columns=MODEL_FEATURES
        )


        # ----------------------------------------------------
        # Generate prediction
        # ----------------------------------------------------

        prediction = model.predict(input_df)

        prediction_value = int(
            prediction[0]
        )


        # ----------------------------------------------------
        # Generate prediction probability
        # ----------------------------------------------------

        probability = None

        if hasattr(model, "predict_proba"):

            probabilities = model.predict_proba(
                input_df
            )

            # XGBoost binary classifier:
            #
            # class 0 -> Low Delay Month
            # class 1 -> High Delay Month
            #
            # Therefore column 1 is the probability of
            # HIGH_DELAY_MONTH = 1.

            probability = float(
                probabilities[0][1]
            )


        # ----------------------------------------------------
        # Human-readable prediction label
        # ----------------------------------------------------

        if prediction_value == 1:

            label = "High Delay Month"

        else:

            label = "Low Delay Month"


        # ----------------------------------------------------
        # Build response
        # ----------------------------------------------------

        response = {
            "prediction": prediction_value,
            "label": label
        }


        # Add probability information when available.

        if probability is not None:

            response["probability"] = probability

            response["high_delay_probability"] = (
                probability
            )

            response["low_delay_probability"] = (
                1.0 - probability
            )


        return response


    # --------------------------------------------------------
    # Re-raise HTTP errors
    # --------------------------------------------------------

    except HTTPException:

        raise


    # --------------------------------------------------------
    # Handle unexpected prediction errors
    # --------------------------------------------------------

    except Exception as e:

        print("=" * 60)
        print("PREDICTION ERROR")
        print("=" * 60)
        print(str(e))
        print("=" * 60)

        raise HTTPException(
            status_code=500,
            detail={
                "error": "Prediction failed",
                "message": str(e)
            }
        ) from e