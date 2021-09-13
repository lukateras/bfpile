import options
import os
import strutils

type
  Command = enum
    MoveRight, MoveLeft, Add, Sub, Write, Read, LoopStart, LoopEnd

  Instruction = ref object
    case command: Command
      of LoopStart, LoopEnd: index: int
      else: times: int

  Target = ref object of RootObj

method header(this: Target) {.base.} = discard
method emit(this: Target, instr: Instruction, i: var int) {.base.} = discard
method footer(this: Target) {.base.} = discard

var commands: seq[Command]

include "targets/aarch64.nimf"
include "targets/c.nimf"
include "targets/interpreter.nim"
include "targets/riscv.nimf"
#include "targets/wasm.nimf"
include "targets/x86.nimf"

let target =
  case toLowerAscii(paramStr(1)):
    of "a", "aarch64", "arm64": Aarch64()
    of "c": C()
    of "i", "interpreter": Interpreter()
    of "r", "risc-v", "riscv": RiscV()
    #of "w", "wasm": Wasm()
    of "x", "x86": X86()
    else: raise newException(ValueError, "Got unknown target platform")

let code = readFile(paramStr(2))

for c in code:
  let cmd = case c:
    of '>': some(MoveRight)
    of '<': some(MoveLeft)
    of '+': some(Add)
    of '-': some(Sub)
    of '.': some(Write)
    of ',': some(Read)
    of '[': some(LoopStart)
    of ']': some(LoopEnd)
    else: none(Command)

  if cmd.isSome:
    commands.add(cmd.get)

var instructions: seq[Instruction]

var times_acc = 1
var loop_matches: seq[Instruction]

for i, c in commands:
  # add the let binding because nim is silly (TODO: report the bug to nim later)
  let c = c
  case c:
    of LoopStart, LoopEnd:
      let instruction = Instruction(command: c, index: instructions.len)
      instructions.add(instruction)
      if c == LoopStart:
        loop_matches.add(instruction)
      else:
        swap(instruction.index, loop_matches.pop.index)
    else:
      if i == commands.len - 1 or c != commands[i + 1]:
        instructions.add(Instruction(command: c, times: times_acc))
        times_acc = 1
      else:
        times_acc += 1

target.header()

var instructions_i = 0

while instructions_i < len(instructions):
  var instr = instructions[instructions_i]
  target.emit(instr, instructions_i)
  instructions_i += 1

target.footer()
