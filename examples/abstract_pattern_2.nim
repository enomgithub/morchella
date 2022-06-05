import std/options
import std/tables

import opengl
import shady
import staticglfw
import vmath

import morchella


proc fragmentShaderAbstractPattern2Proc(
  gl_FragCoord: Vec4,
  resolution: Uniform[Vec2],
  time: Uniform[float32],
  gl_FragColor: var Vec4
) =
  var
    uv = (gl_FragCoord.xy * 2.0 - resolution.xy) / min(resolution.x, resolution.y)
    division = 16.0
    x = ceil(vec2(division) * sin(vec2(time))) / vec2(division) * sin(uv)
    y = dot(uv, x)
    z = abs(y)
    r = ceil((sin(time * z * 1.0) * sin(ceil(length(uv) * division) + 1.0 * sin(time)) + 1.0) *
        division) / division
    g = ceil((sin(time * z * 3.0) * sin(ceil(length(uv) * division) + 3.0 * sin(time)) + 1.0) *
        division) / division
    b = ceil((sin(time * z * 5.0) * sin(ceil(length(uv) * division) + 5.0 * sin(time)) + 1.0) *
        division) / division
  var color = vec3(r, g, b)
  gl_FragColor = vec4(color, 1.0)


proc renderAbstractPattern1(
  window: Window,
  program: GLuint,
  uniformLocations: seq[(string, string, GLuint)],
  startTime: float32
) =
  var
    resolution = window.getResolution()
    time = getTime(startTime)

  let fUniformNameToPtr = {
    "resolution": resolution[0].addr(),
    "time": time.addr()
  }.toTable()

  render(
    window,
    program,
    resolution,
    fUniformNameToPtr = some(fUniformNameToPtr),
    uniformLocations = uniformLocations
  )


proc play(): int =
  let
    version = (4, 1)
    fragmentShaderText = fragmentShaderAbstractPattern2Proc.toGLSL(version = "410")
    fragmentShaderUniforms = fragmentShaderAbstractPattern2Proc.fetchUniforms()

    (window, program, uniformLocations, startTime) = initialize(
      size = (500, 500),
      title = "Abstract Pattern #2",
      version,
      fragmentShaderText,
      fragmentShaderUniforms
    )

  echo "Initialize done."

  while window.windowShouldClose() == 0:
    renderAbstractPattern1(window, program, uniformLocations, startTime)
    pollEvents()

  return 0


when isMainModule:
  quit(play())
