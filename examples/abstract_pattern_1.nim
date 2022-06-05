import std/options
import std/tables

import opengl
import shady
import staticglfw
import vmath

import morchella
import morchella/math


proc fragmentShaderAbstractPattern1Proc(
  gl_FragCoord: Vec4,
  resolution: Uniform[Vec2],
  time: Uniform[float32],
  gl_FragColor: var Vec4
) =
  var
    uv = (gl_FragCoord.xy * 2.0 - resolution.xy) / min(resolution.x, resolution.y)
    a = vec2(sin(time), cos(time)) + uv
    b = vec2(cos(time), sin(time)) + uv
    c = dot(vec2(hashOld12(a - vec2(hash12(b)))), uv)
    division = 64.0
    d = length(vec3(division) * vec3(uv, 0.5) - fract(vec3(division) * vec3(uv, 0.5)))
    color = vec3(
      smin(sin(c), cos(d), sin(time)) * sin(c + d),
      smin(sin(c), cos(d), sin(time)) * sin(smin(c, d, time) + 5.0 * d),
      smin(sin(c), cos(d), sin(time)) * sin(c + d + time + 10.0 * hash12(vec2(d)))
    ) 
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
    fragmentShaderText = fragmentShaderAbstractPattern1Proc.toGLSL(version = "410")
    fragmentShaderUniforms = fragmentShaderAbstractPattern1Proc.fetchUniforms()

    (window, program, uniformLocations, startTime) = initialize(
      size = (500, 500),
      title = "Abstract Pattern #1",
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
