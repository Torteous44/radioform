## Summary
- 
- 

## Testing
- [ ] DSP: `cmake -S packages/dsp -B packages/dsp/build -DCMAKE_BUILD_TYPE=Release && cmake --build packages/dsp/build --config Release --parallel`
- [ ] DSP tests: `cd packages/dsp/build && ctest --output-on-failure`
- [ ] Host: `swift build --configuration release --package-path packages/host` (after building DSP)
- [ ] Driver: `cmake -S packages/driver -B packages/driver/build -DCMAKE_BUILD_TYPE=Release && cmake --build packages/driver/build --config Release --parallel` (requires libASPL vendor drop + macOS)
- [ ] Web: `cd apps/web/site && npm ci && npm run lint && npm run build`
- [ ] Not run (explain):

## Risk / rollout
- User-facing impact and rollback plan (e.g., uninstall driver, stop host, revert preset format).
