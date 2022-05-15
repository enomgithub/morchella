import std/macros
import std/sequtils
import std/sugar
import std/tables
import std/times

import opengl
import shady
import staticglfw
import vmath


const typeToUniformProc = {
  "float32": glUniform1fv,
  "Vec2": glUniform2fv,
  "Vec3": glUniform3fv,
  "Vec4": glUniform4fv
}.toTable()


proc vertexShaderBasic(
  gl_Position: var Vec4,
  position: Vec2
) =
  gl_Position = vec4(position.x, position.y, 0.0, 1.0)


proc checkError(shader: GLuint) =
  var code: GLint
  glGetShaderiv(shader, GL_COMPILE_STATUS, code.addr())

  if code.GLboolean == GL_TRUE:
    return

  var length: GLint = 0
  glGetShaderiv(shader, GL_INFO_LOG_LENGTH, length.addr())
  var log = newString(length.int)
  glGetShaderInfoLog(shader, length, nil, cstring(log))
  echo log


proc initializeWindow(
  size: tuple[width: int, height: int],
  title: string,
  version: tuple[major: int, minor: int]
): Window =
  const titlePrefix = "Morchella"

  windowHint(SAMPLES, 0)
  windowHint(CONTEXT_VERSION_MAJOR, version.major.cint())
  windowHint(CONTEXT_VERSION_MINOR, version.minor.cint())

  let window = createWindow(
    size.width.cint(),
    size.height.cint(),
    (titlePrefix & " - " & title & " - ").cstring(),
    nil,
    nil
  )
  window.makeContextCurrent()

  return window


proc fetchUniformsInner*(procNode: NimNode): seq[(string, string)] =
  ## Return list of Uniform fetched out of a shader proc implementation.
  ## procNode is assumed nnkSym (symbol),
  ## and topNode is assumed nnkProcDef (define of proc) or nnkFuncDef (define of func).

  let topNode = procNode.getImpl()
  echo $topNode.kind()
  var uniforms: seq[(string, string)] = @[]

  for node in topNode:
    case node.kind()
    of nnkSym:
      # Node that means a name of proc or func
      echo "  " & $node.kind() & ": " & $node
    of nnkFormalParams:
      # Node that means list of arguments
      echo "  " & $node.kind()
      for subNode in node:
        case subNode.kind()
        of nnkIdentDefs:
          # Node that means define of arguments
          echo "    " & $subNode.kind()
          case subNode[0].kind()
          of nnkSym:
            # Node that means a name of a argument
            echo "      " & $subNode[0].kind() & ": " & $subNode[0]
            case subNode[1].kind()
            of nnkBracketExpr:
              # Like a type of Uniform[Vec2]
              echo "      " & $subNode[1].kind()
              if $subNode[1][0] == "Uniform":
                echo "        " & $subNode[1][0].kind() & ": " & $subNode[1][0]
                echo "        " & $subNode[1][1].kind() & ": " & $subNode[1][1]
                let pair = ($subNode[0], $subNode[1][1])
                uniforms.add(pair)
            of nnkVarTy:
              # Like a type of var Vec2 (mutable argument)
              echo "      " & $subNode[1].kind()
              echo "        " & $subNode[1][0].kind() & ": " & $subNode[1][0]
            else:
              echo "      " & $subNode[1].kind()
          else:
            echo "      " & $subNode[0].kind()
            echo "      " & $subNode[1].kind()
        of nnkEmpty:
          echo "    " & $subNode.kind()
        else:
          echo "    " & $subNode.kind() & ": " & $subNode
    else:
      echo "  " & $node.kind()
  echo ""

  return uniforms


macro fetchUniforms*(shaderProc: typed): seq[(string, string)] =
  assert shaderProc.getImpl().kind() in {nnkFuncDef, nnkProcDef}
  newLit(fetchUniformsInner(shaderProc))


proc initialize*(
  size: tuple[width: int, height: int],
  title: string,
  version: tuple[major: int, minor: int],
  fragmentShaderText: string,
  fragmentShaderUniforms: seq[(string, string)]
): (Window, GLuint, seq[(string, string, GLuint)], float32) =
  if init() == 0:
    raise newException(Exception, "Failed to Initialize GLFW")

  var window = initializeWindow(size, title, version)

  when not defined(emscripten):
    loadExtensions()

  const
    exponent = 4
  var
    vertices: array[0 .. 11, float32] = [
      -1.0f, 1.0f,
      -1.0f, -1.0f,
      1.0f, -1.0f,
      -1.0f, 1.0f,
      1.0f, -1.0f,
      1.0f, 1.0f
    ]

  var vertexArrayId: GLuint
  glGenVertexArrays(1, vertexArrayId.addr())
  glBindVertexArray(vertexArrayId)

  var vertexBuffer: GLuint
  glGenBuffers(1, vertexBuffer.addr())
  glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer)
  glBufferData(GL_ARRAY_BUFFER, vertices.len * exponent, vertices[0].addr(), GL_STATIC_DRAW)

  var
    vertexShaderText = vertexShaderBasic.toGLSL("410")

  var
    vertexShader = glCreateShader(GL_VERTEX_SHADER)
    vertexShaderTextArray = allocCStringArray([vertexShaderText])
  glShaderSource(vertexShader, 1.GLsizei, vertexShaderTextArray, nil)
  glCompileShader(vertexShader)
  checkError(vertexShader)
  echo vertexShaderText

  var
    fragmentShader = glCreateShader(GL_FRAGMENT_SHADER)
    fragmentShaderTextArray = allocCStringArray([fragmentShaderText])
  glShaderSource(fragmentShader, 1.GLsizei, fragmentShaderTextArray, nil)
  glCompileShader(fragmentShader)
  checkError(fragmentShader)
  echo fragmentShaderText

  var program = glCreateProgram()
  glAttachShader(program, vertexShader)
  glAttachShader(program, fragmentShader)
  glLinkProgram(program)

  let positionLocation = glGetAttribLocation(program, "position").GLuint
  
  glVertexAttribPointer(positionLocation, 2.GLint, cGL_FLOAT, GL_FALSE, 0.GLsizei, nil)
  glEnableVertexAttribArray(positionLocation)

  let
    startTime = epochTime().float32()
    uniformLocations = fragmentShaderUniforms.map((uniform: (string, string)) => (
      uniform[0],
      uniform[1],
      glGetUniformLocation(program, uniform[0].cstring()).GLuint
    )) 

  (window, program, uniformLocations, startTime)


proc getResolution*(window: Window): array[0..1, float32] =
  var width, height: cint
  getFramebufferSize(window, width.addr(), height.addr())
  return [width.float32(), height.float32()]


proc getTime*(startTime: float32): float32 =
  return epochTime() - startTime


proc render*(
  window: Window,
  program: GLuint,
  resolution: array[0..1, float32],
  uniformNameToPtr: Table[string, ptr float32],
  uniformLocations: seq[(string, string, GLuint)]
) =
  glViewport(0, 0, resolution[0].GLsizei(), resolution[1].GLsizei())
  glClearColor(0, 0, 0, 1)
  glClear(GL_COLOR_BUFFER_BIT)

  glUseProgram(program)

  for (uniformName, uniformType, uniformLocation) in uniformLocations:
    let uniformProc = typeToUniformProc.getOrDefault(uniformType, nil)
    assert not uniformProc.isNil()

    let uniformValuePtr = uniformNameToPtr.getOrDefault(uniformName, nil)
    assert not uniformValuePtr.isNil()

    uniformProc(uniformLocation.GLint, 1, uniformValuePtr)
  glDrawArrays(GL_TRIANGLES, 0, 6)

  window.swapBuffers()
