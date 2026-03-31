import * as logger from "firebase-functions/logger";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {region} from "./shared/firebase.js";
import {getNowJstParts} from "./shared/rankings.js";
import {refreshRacerDataset} from "./shared/racerDatasetRefresh.js";

export const refreshRacerDatasetOnSchedule = onSchedule({
  region,
  schedule: "0 0 1 1,7 *",
  timeZone: "Asia/Tokyo",
  timeoutSeconds: 540,
  memory: "1GiB",
}, async (event) => {
  const datasetId = getNowJstParts(new Date(event.scheduleTime)).term;
  logger.info("refreshRacerDatasetOnSchedule started", {datasetId});
  const result = await refreshRacerDataset(datasetId, {
    syncImages: true,
    clear: true,
    setCurrent: true,
  });
  logger.info("refreshRacerDatasetOnSchedule completed", result);
});
