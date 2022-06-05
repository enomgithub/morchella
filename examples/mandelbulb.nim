# This implementation was heavily influenced by
# https://github.com/pedrotrschneider/shader-fractals/blob/main/3D/Mandelbulb.glsl

import std/options
import std/tables

import shady
import staticglfw
import vmath

import morchella
import morchella/math


proc rot(angle: float32, v: Vec2): Vec2 =
  var
    s: float32 = sin(angle)
    c: float32 = cos(angle)
  return vec2(v.x * c + v.y * s, -v.x * s + v.y * c)



proc r(uv: Vec2, p: Vec3, l: Vec3, z: float32): Vec3 =
  var
    f: Vec3 = normalize(l - p)
    r: Vec3 = normalize(cross(vec3(0.0, 1.0, 0.0), f))
    u: Vec3 = cross(f, r)
    c: Vec3 = p + f * vec3(z)
    i: Vec3 = c + vec3(uv.x) * r + vec3(uv.y) * u
    d: Vec3 = normalize(i - p)
  return d


proc hsv2rgb(c: Vec3): Vec3 =
  var
    k: Vec4 = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0)
    p: Vec3 = abs(fract(c.xxx + k.xyz) * 6.0 - k.www)
    val: Vec3 = p - k.xxx
    clampVal: Vec3 = vec3(
      clamp(val.x, (0.0).float32(), (1.0).float32()),
      clamp(val.y, (0.0).float32(), (1.0).float32()),
      clamp(val.z, (0.0).float32(), (1.0).float32())
    )
  return vec3(c.z) * mix(k.xxx, clampVal, c.y)


proc map(value: float32, min1: float32, max1: float32, min2: float32, max2: float32): float32 =
  return min2 + (value - min1) * (max2 - min2) / (max1 - min1)


proc mandelbulb(position: Vec3, time: float32): float32 =
  var
    z: Vec3 = position
    dr: float32 = 1.0
    r: float32 = 0.0
    iterations: int32 = 0
    power: float32 = 8.0 + (5.0 * map(sin(time * PI / 10.0 + PI), -1.0, 1.0, 0.0, 1.0))

  for i in 0..<10:
    iterations = i.int32()
    r = length(z)

    if r > 2.0:
      break

    var
      theta: float32 = acos(z.z / r)
      phi: float32 = atan(z.y, z.x)
      zr: float32 = pow(r, power)

    dr = pow(r, power - 1.0) * power * dr + 1.0
    theta = theta * power
    phi = phi * power

    z = vec3(zr) * vec3(sin(theta) * cos(phi), sin(phi) * sin(theta), cos(theta))
    z += position
  
  var dst: float32 = 0.5 * log(r) * r / dr
  return dst


proc distanceEstimator(p: Vec3, time: float32): float32 =
  var
    pp: Vec3 = p
    temp: Vec2 = rot((-0.3 * PI).float32(), pp.yz)
  pp = vec3(pp.x, temp.x, temp.y)
  var mandelbulbVal: float32 = mandelbulb(pp, time)
  return mandelbulbVal


const
  maximumRaySteps: int32 = 250
  maximumDistance: float32 = 200.0
  minimumDistance: float32 = 0.0001


proc rayMarcher(ro: Vec3, rd: Vec3, time: float32): Vec4 =
  var
    steps: int32 = 0
    totalDistance: float32 = 0.0f
    minDistToScene: float32 = 100.0f
    minDistToScenePos: Vec3 = ro
    minDistToOrigin: float32 = 100.0f
    minDistToOriginPos: Vec3 = ro
    col: Vec3 = vec3(0.0, 0.0, 0.0)
    curPos: Vec3 = ro
    hit: bool = false
  
  for s in 0..<maximumRaySteps:
    steps = s.int32()
    var
      p: Vec3 = ro + vec3(totalDistance) * rd
      distance: float32 = distanceEstimator(p, time)

    curPos = ro + rd * vec3(totalDistance)
    if minDistToScene > distance:
      minDistToScene = distance
      minDistToScenePos = curPos
    
    if minDistToOrigin > length(curPos):
      minDistToOrigin = length(curPos)
      minDistToOriginPos = curPos
    
    totalDistance += distance
    if distance < minimumDistance:
      hit = true
      break
    elif distance > maximumDistance:
      break
  
  if hit:
    col = vec3(0.8 + (length(curPos) / 0.5), 1.0, 0.8)
    col = hsv2rgb(col)
  else:
    col = vec3(0.8 + (length(minDistToScenePos) / 0.5), 1.0, 0.8)
    col = hsv2rgb(col)
    col = col * vec3(1.0 / (minDistToScene * minDistToScene))
    col = col / vec3(map(sin(time * 3.0), -1.0, 1.0, 3000.0, 50000.0))
  
  col = col / vec3(steps.float32() * 0.08)
  col = col / vec3(pow(abs(length(ro) - length(minDistToScenePos)), 2.0))
  col = col * vec3(3.0)

  return vec4(col, 1.0)


proc fragmentShaderProc(
  gl_FragCoord: Vec4,
  resolution: Uniform[Vec2],
  time: Uniform[float32],
  gl_FragColor: var Vec4
) =
  var uv: Vec2 = (gl_FragCoord.xy - vec2(0.5) * resolution.xy) / min(resolution.x, resolution.y)
  uv = uv * vec2(1.5)
  var
    ro: Vec3 = vec3(0.0, 0.0, -2.0)
    rd: Vec3 = r(uv, ro, vec3(0.0, 0.0, 1.0), (1.0).float32())
    col: Vec4 = rayMarcher(ro, rd, time)
  
  gl_FragColor = col


proc play(): int =
  let
    version = (4, 1)
    fragmentShaderText = fragmentShaderProc.toGLSL(version = "410")
    fragmentShaderUniforms = fragmentShaderProc.fetchUniforms()
  
    (window, program, uniformLocations, startTime) = initialize(
      size = (500, 500),
      title = "Mandelbulb",
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
