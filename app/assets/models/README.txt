Place a licensed inpainting ONNX model here as `inpainting.onnx` when running PoC (see docs/spec.md §4.1).
Until then, the app uses StubInpaintingEngine for UI flow; OnnxInpaintingEngine reports a clear error if the file is missing.

Do not commit large binary weights to git without LFS and license review.
