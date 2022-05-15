import std/tables

import opengl
import shady
import staticglfw
import vmath

import morchella
import morchella/math


proc fragmentShaderFlowerPattern(
  gl_FragCoord: Vec4,
  resolution: Uniform[Vec2],
  amplitude: Uniform[Vec3],
  phase: Uniform[Vec3],
  frequency: Uniform[Vec3],
  time: Uniform[float32],
  gl_FragColor: var Vec4
) =
  let 
    p: Vec2 = (gl_FragCoord.xy * vec2(2.0, 2.0) - resolution.xy) / min(resolution.x, resolution.y)
    r = 0.01 / abs(
      0.5 +
      amplitude.x *
        sin(
          (atan(p.y, p.x) + (time + phase.x) * 0.1) *
          frequency.x
        ) *
        0.01 -
      length(p)
    )
    g = 0.01 / abs(
      0.5 +
      amplitude.y *
        sin(
          (atan(p.y, p.x) + (time + phase.y) * 0.1) *
          frequency.y
        ) *
        0.01 -
      length(p)
    )
    b = 0.01 / abs(
      0.5 +
      amplitude.z *
        sin(
          (atan(p.y, p.x) + (time + phase.z) * 0.1) *
          frequency.z
        ) *
        0.01 -
      length(p)
    )

  gl_FragColor = vec4(r, g, b, 1.0)


proc getAmplitude(): array[0..2, float32] = 
  return [1.float32(), 10.float32(), 20.float32()]


proc getPhase(): array[0..2, float32] = 
  return [10.float32(), 30.float32(), 50.float32()]


proc getFrequency(): array[0..2, float32] = 
  return [10.float32(), 30.float32(), 50.float32()]


proc renderFlowerPattern(
  window: Window,
  program: GLuint,
  typeToUniformProc: Table[string,proc],
  uniformLocations: seq[(string, string, GLuint)],
  startTime: float32
) =
  var
    resolution = window.getResolution()
    amplitude = getAmplitude()
    phase = getPhase()
    frequency = getFrequency()
    time = getTime(startTime)

  let uniformNameToPtr = {
    "resolution": resolution[0].addr(),
    "amplitude": amplitude[0].addr(),
    "phase": phase[0].addr(),
    "frequency": frequency[0].addr(),
    "time": time.addr()
  }.toTable()

  render(
    window,
    program,
    resolution,
    uniformNameToPtr,
    typeToUniformProc,
    uniformLocations
  )


proc main() =
  let
    version = (4, 1)
    fragmentShaderText = fragmentShaderFlowerPattern.toGLSL(version = "410")
    fragmentShaderUniforms = fragmentShaderFlowerPattern.fetchUniforms()

    (window, program, uniformLocations, startTime) = initialize(
      size = (500, 500),
      title = "Flower Pattern",
      version,
      fragmentShaderText,
      fragmentShaderUniforms
    )

  echo "Initialize done."

  while window.windowShouldClose() == 0:
    renderFlowerPattern(window, program, typeToUniformProc, uniformLocations, startTime)
    pollEvents()


when isMainModule:
  main()
