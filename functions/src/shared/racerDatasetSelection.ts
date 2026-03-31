import {db} from "./firebase.js";
import type {RacerDatasetSelection} from "./types.js";
import {requireString} from "./validation.js";

const racerDatasetStateDocPath = "app_config/racer_dataset_state";

export async function resolveRacerDatasetSelection(query: {
  datasetId?: unknown;
}): Promise<RacerDatasetSelection> {
  const explicitDatasetId = requireString(query.datasetId);
  if (explicitDatasetId) {
    return {
      datasetId: explicitDatasetId,
      source: "explicit",
    };
  }

  const stateSnapshot = await db.doc(racerDatasetStateDocPath).get();
  if (!stateSnapshot.exists) {
    throw new Error("racer_dataset_state_missing");
  }

  const currentDatasetId = requireString(stateSnapshot.get("currentDatasetId"));
  if (currentDatasetId) {
    return {
      datasetId: currentDatasetId,
      source: "current",
    };
  }

  const fallbackDatasetId = requireString(stateSnapshot.get("fallbackDatasetId"));
  if (!fallbackDatasetId) {
    throw new Error("fallback_racer_dataset_missing");
  }

  return {
    datasetId: fallbackDatasetId,
    source: "fallback",
  };
}
