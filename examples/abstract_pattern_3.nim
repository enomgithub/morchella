import std/options
import std/tables

import shady
import staticglfw
import vmath

import morchella
import morchella/math


proc fragmentShaderAbstractPattern3Proc(
  gl_FragCoord: Vec4,
  resolution: Uniform[Vec2],
  time: Uniform[float32],
  gl_FragColor: var Vec4
) =
  var
    uv = (gl_FragCoord.xy * 2.0 - resolution.xy) / min(resolution.x, resolution.y)
    noise = hashOld12(uv * time)
    col =
      1.0 -
      clamp(floor(length(uv) + 0.5), 0.0, 1.0) *
      clamp(floor(length(uv + 1.0) + 0.5), 0.0, 1.0) *
      clamp(floor(length(uv - 1.0) + 0.5), 0.0, 1.0) *
      clamp(floor(length(uv + vec2(1.0, -1.0)) + 0.5), 0.0, 1.0) *
      clamp(floor(length(uv + vec2(-1.0, 1.0)) + 0.5), 0.0, 1.0) *
      noise
  var color = vec3(col, col, col)
  gl_FragColor = vec4(color, 1.0)


proc play(): int =
  let
    version = (4, 1)
    fragmentShaderText = fragmentShaderAbstractPattern3Proc.toGLSL(version = "410")
    fragmentShaderUniforms = fragmentShaderAbstractPattern3Proc.fetchUniforms()

    (window, program, uniformLocations, startTime) = initialize(
      size = (500, 500),
      title = "Abstract Pattern #3",
      version,
      fragmentShaderText,
      fragmentShaderUniforms
    )

  echo "Initialize done."

  var
    resolution: array[0..1, float32]
    time: float32

  let fUniformNameToPtr = {
    "resolution": resolution[0].addr(),
    "time": time.addr()
  }.toTable()

  while window.windowShouldClose() == 0:
    resolution = window.getResolution()
    time = getTime(startTime)

    render(
      window,
      program,
      resolution,
      fUniformNameToPtr = some(fUniformNameToPtr),
      uniformLocations = uniformLocations
    )

    pollEvents()

  return 0


when isMainModule:
  quit(play())
