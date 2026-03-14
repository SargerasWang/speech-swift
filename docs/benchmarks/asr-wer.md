# ASR Word Error Rate (WER) Benchmark

## Dataset

**LibriSpeech test-clean** — 2620 utterances, ~5.4 hours of read English speech.

## Results

| Model | Bits | WER% | Substitutions | Insertions | Deletions | RTF | Model Load | Warmup |
|-------|------|------|---------------|------------|-----------|-----|------------|--------|
| Qwen3-ASR 0.6B | 4-bit | 3.34 | 1323 | 123 | 308 | 0.023 | 2.4s | 0.3s |
| Qwen3-ASR 0.6B | 8-bit | 2.80 | 1111 | 92 | 268 | 0.025 | 2.4s | 0.5s |

**Machine**: Apple M2 Max, 64 GB, macOS 14, release build with compiled metallib.

## Context

| Model | WER% (test-clean) | Source |
|-------|-------------------|--------|
| Whisper Large v3 | ~2.7 | OpenAI |
| Qwen3-ASR 0.6B 8-bit | 2.80 | This benchmark |
| Qwen3-ASR 0.6B 4-bit | 3.34 | This benchmark |

## Compression delta

4-bit quantization adds 0.54% WER vs 8-bit (3.34% vs 2.80%). 8-bit is 16% better on error count. Model size difference: ~200 MB (8-bit) vs ~120 MB (4-bit).

## Reproduction

```bash
make build
python scripts/benchmark_asr.py --batch --engine qwen3 --model 0.6B
python scripts/benchmark_asr.py --batch --engine qwen3 --model 0.6B-8bit
```

First run downloads LibriSpeech test-clean (~350 MB). Results saved to `benchmarks/librispeech/`.
