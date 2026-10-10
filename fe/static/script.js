// ============================================================
// FLIGHT DELAY PREDICTOR - FRONTEND JAVASCRIPT
// ============================================================

let probabilityChart = null;


// ============================================================
// INITIALIZE AFTER PAGE LOAD
// ============================================================

document.addEventListener("DOMContentLoaded", () => {

    const predictionForm =
        document.getElementById("predictionForm");

    if (!predictionForm) {
        console.error("ERROR: predictionForm was not found.");
        return;
    }

    console.log("Flight Delay Predictor JavaScript loaded successfully.");

    predictionForm.addEventListener(
        "submit",
        handlePrediction
    );

});


// ============================================================
// HANDLE PREDICTION
// ============================================================

async function handlePrediction(event) {

    // Stop the browser's native form submission (GET + reload).
    event.preventDefault();

    console.log("Predict submitted.");

    const airline =
        document.getElementById("airline").value;

    const month =
        Number(document.getElementById("month").value);

    const prevArrivalDelayRate =
        Number(document.getElementById("prevArrivalDelayRate").value);

    const prevAvgArrDelay =
        Number(document.getElementById("prevAvgArrDelay").value);

    const prevTotalFlights =
        Number(document.getElementById("prevTotalFlights").value);

    const prevCancellationRate =
        Number(document.getElementById("prevCancellationRate").value);

    const predictButton =
        document.getElementById("predictButton");

    console.log("Input values:", {
        airline,
        month,
        prevArrivalDelayRate,
        prevAvgArrDelay,
        prevTotalFlights,
        prevCancellationRate
    });


    // ========================================================
    // VALIDATION
    // ========================================================

    if (!airline) {
        showError("Please select an airline.");
        return;
    }

    if (!month || month < 1 || month > 12) {
        showError("Please select a valid prediction month.");
        return;
    }

    if (
        !Number.isFinite(prevArrivalDelayRate) ||
        prevArrivalDelayRate < 0 ||
        prevArrivalDelayRate > 1
    ) {
        showError("Previous Arrival Delay Rate must be between 0 and 1.");
        return;
    }

    if (!Number.isFinite(prevAvgArrDelay)) {
        showError("Please enter a valid Previous Average Arrival Delay.");
        return;
    }

    if (
        !Number.isFinite(prevTotalFlights) ||
        prevTotalFlights < 0
    ) {
        showError("Previous Total Flights must be 0 or greater.");
        return;
    }

    if (
        !Number.isFinite(prevCancellationRate) ||
        prevCancellationRate < 0 ||
        prevCancellationRate > 1
    ) {
        showError("Previous Cancellation Rate must be between 0 and 1.");
        return;
    }


    // ========================================================
    // DISABLE BUTTON
    // ========================================================

    predictButton.disabled = true;
    predictButton.textContent = "Predicting...";

    try {

        const requestBody = {
            AIRLINE: airline,
            MONTH: month,
            PREV_ARRIVAL_DELAY_RATE: prevArrivalDelayRate,
            PREV_AVG_ARR_DELAY: prevAvgArrDelay,
            PREV_TOTAL_FLIGHTS: Math.round(prevTotalFlights),
            PREV_CANCELLATION_RATE: prevCancellationRate
        };

        console.log("Sending prediction request:", requestBody);

        const response = await fetch("/predict", {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify(requestBody)
        });

        console.log("FastAPI response status:", response.status);

        const data = await response.json();

        console.log("FastAPI response:", data);

        if (!response.ok) {

            let errorMessage = "Prediction failed.";

            if (data && data.detail) {

                if (typeof data.detail === "string") {
                    errorMessage = data.detail;

                } else if (data.detail.message) {
                    errorMessage = data.detail.message;

                } else if (Array.isArray(data.detail)) {
                    // FastAPI/Pydantic validation errors (422)
                    errorMessage = data.detail
                        .map(d => `${(d.loc || []).join(".")}: ${d.msg}`)
                        .join("; ");
                }
            }

            throw new Error(errorMessage);
        }

        displayPrediction(data);

    } catch (error) {

        console.error("Prediction request failed:", error);

        showError(
            error.message ||
            "Unable to connect to the prediction server."
        );

    } finally {

        predictButton.disabled = false;
        predictButton.textContent = "Predict";

    }

}


// ============================================================
// DISPLAY PREDICTION
// ============================================================

function displayPrediction(data) {

    const resultPlaceholder =
        document.querySelector(".result-placeholder");

    const resultContent =
        document.getElementById("resultContent");

    // showError() replaces resultContent's innerHTML, so rebuild
    // the result markup if a previous error removed it.
    if (!document.getElementById("predictionText")) {
        resultContent.innerHTML = `
            <div class="result-label">Prediction</div>
            <div class="prediction-text" id="predictionText">—</div>
            <div class="probability-container">
                <div class="probability-header">
                    <span>High Delay Probability</span>
                    <strong id="probabilityText">—</strong>
                </div>
                <div class="progress-background">
                    <div class="progress-bar" id="progressBar"></div>
                </div>
            </div>
            <div class="chart-container">
                <canvas id="probabilityChart"></canvas>
            </div>
        `;
        probabilityChart = null;
    }

    const predictionText =
        document.getElementById("predictionText");

    const probabilityText =
        document.getElementById("probabilityText");

    const progressBar =
        document.getElementById("progressBar");

    resultPlaceholder.style.display = "none";
    resultContent.style.display = "block";

    predictionText.textContent =
        data.label || "Prediction";

    if (data.high_delay_probability !== undefined) {

        const highPercentage =
            Number(data.high_delay_probability) * 100;

        const lowPercentage =
            Number(data.low_delay_probability) * 100;

        probabilityText.textContent =
            `${highPercentage.toFixed(1)}%`;

        progressBar.style.width =
            `${highPercentage}%`;

        createProbabilityChart(
            highPercentage,
            lowPercentage
        );

    } else {

        probabilityText.textContent = "Not available";
        progressBar.style.width = "0%";

    }

}


// ============================================================
// CREATE PROBABILITY CHART
// ============================================================

function createProbabilityChart(highProbability, lowProbability) {

    const chartCanvas =
        document.getElementById("probabilityChart");

    if (!chartCanvas) {
        console.error("Probability chart canvas not found.");
        return;
    }

    if (typeof Chart === "undefined") {
        console.error("Chart.js did not load (CDN blocked/offline?).");
        return;
    }

    if (probabilityChart !== null) {
        probabilityChart.destroy();
    }

    probabilityChart = new Chart(chartCanvas, {

        type: "doughnut",

        data: {
            labels: ["High Delay", "Low Delay"],
            datasets: [{
                data: [highProbability, lowProbability],
                borderWidth: 0
            }]
        },

        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                legend: {
                    position: "bottom"
                },
                tooltip: {
                    callbacks: {
                        label: function (context) {
                            return `${context.label}: ` +
                                   `${context.parsed.toFixed(1)}%`;
                        }
                    }
                }
            }
        }

    });

}


// ============================================================
// SHOW ERROR
// ============================================================

function showError(message) {

    const resultPlaceholder =
        document.querySelector(".result-placeholder");

    const resultContent =
        document.getElementById("resultContent");

    resultPlaceholder.style.display = "none";
    resultContent.style.display = "block";

    // The old canvas is destroyed along with the innerHTML below.
    if (probabilityChart !== null) {
        probabilityChart.destroy();
        probabilityChart = null;
    }

    resultContent.innerHTML = `
        <div class="error-message">
            <strong>Prediction Error</strong>
            <br><br>
            ${escapeHtml(message)}
        </div>
    `;

}


// ============================================================
// HTML ESCAPE
// ============================================================

function escapeHtml(value) {

    return String(value)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");

}