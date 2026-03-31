export function setCorsHeaders(response: {
  set: (field: string, value: string) => void;
}) {
  response.set("Access-Control-Allow-Origin", "*");
  response.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  response.set("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
}

export function handleOptions(requestMethod: string, response: {
  status: (code: number) => {send: (body?: string) => void};
}) {
  if (requestMethod === "OPTIONS") {
    response.status(204).send("");
    return true;
  }

  return false;
}

export function sendError(
  response: {
    status: (code: number) => {json: (body: Record<string, unknown>) => void};
  },
  status: number,
  error: string,
  message: string,
) {
  response.status(status).json({error, message});
}
