import {Timestamp} from "firebase-admin/firestore";

import {requirePositiveInteger} from "./validation.js";

export function timestampToIsoString(value: unknown): string | null {
  return value instanceof Timestamp ? value.toDate().toISOString() : null;
}

export function getDatasetUpdatedAtIso(data: Record<string, unknown>): string | null {
  return timestampToIsoString(data.datasetUpdatedAt) ??
    timestampToIsoString(data.updatedAt);
}

export function getImagePackResponse(data: Record<string, unknown>) {
  const storagePath = typeof data.imagePackStoragePath === "string" &&
      data.imagePackStoragePath ?
    data.imagePackStoragePath :
    null;
  const updatedAt = timestampToIsoString(data.imagePackUpdatedAt);
  const imageCount = requirePositiveInteger(data.imagePackImageCount);
  const byteSize = requirePositiveInteger(data.imagePackByteSize);

  if (!storagePath || !updatedAt || imageCount == null || byteSize == null) {
    return null;
  }

  return {
    storagePath,
    updatedAt,
    imageCount,
    byteSize,
  };
}

export function mapRacerResponse(id: string, data: Record<string, unknown>) {
  return {
    id,
    name: data.name ?? null,
    nameKana: data.nameKana ?? null,
    registrationNumber: data.registrationNumber ?? null,
    class: data.class ?? null,
    gender: data.gender ?? null,
    imageUrl: data.imageUrl ?? null,
    imageStoragePath: data.imageStoragePath ?? null,
    imageSource: data.imageSource ?? null,
    updatedAt: timestampToIsoString(data.updatedAt),
    isActive: data.isActive ?? null,
  };
}
