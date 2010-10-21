//
// Copyright (c) 2010, Ivan Grishulenko
// Licensed under the Academic Free License version 3.0
//
// History:
//   In past     Ivan Grishulenko  Creation
//   2010-07-02  Ivan Grishulenko  Refactoring
//   2010-07-03  Ivan Grishulenko  Bug fixing
//

using compiler
using util

class ViewServer
{
  // Constructor. Support your own i/o streams if needed
  new make(InStream inputStream := Env.cur.in, OutStream outputStream := Env.cur.out)
  {
    this.input = JsonInStream(inputStream)
    this.output = JsonOutStream.make(outputStream)
    this.compilationCycle = 0
    this.pods = Pod[,]
  }

  // Run the view server
  Void run()
  {
    this.log("Starting")
    try
    {
      while (true)
      {
        List r := this.input.readJson
        this.log("Command: ${r[0]}")
        switch (r[0])
        {
          case "add_fun":
            this.addFun(r[1])
          case "map_doc":
            this.mapDoc(r[1])
          case "reduce":
            this.reduce(r[1], r[2])
          case "rereduce":
            this.rereduce(r[1], r[2])
          case "reset":
            this.reset
          case "die":
            // Extension to viewserver commands
            break
          default:
            this.log("Unknown command: ${r[0]}")
        }
      }
      this.output.flush
    }
    catch (Err e)
    {
      this.log("Got an error while running a server: " + e.toStr + e.traceToStr)
      return
    }
  }

  // Add new entry to the couchdb log
  private Void log(Str message)
  {
    this.output.writeJson(["log", message])
    this.output.write('\n')
  }

  // Report an error
  private Void logError(Str errorCode, Str message)
  {
    this.output.writeJson(["error": errorCode, "reason": message])
    this.output.write('\n')
  }

  // Reset view server
  private Void reset()
  {
    this.pods.clear
    this.output.writeChars("true")
    this.output.write('\n')
  }

  // Compile & add new function
  private Void addFun(Str source)
  {
    try
    {
      this.pods.add(this.compile(source))

      this.output.writeChars("true")
      this.output.write('\n')
    }
    catch (Err e)
    {
      this.logError("1", e.toStr + e.traceToStr)
    }
  }

  // Map a document
  private Void mapDoc(Obj:Obj doc)
  {
    //Obj doc := JsonInStream.make(docSource.in).readJson
    results := [,]
    this.pods.each |pod|
    {
      try
      {
        Method f := pod.type("Temporary").method("map")
        results.addAll(f.call(doc))
      }
      catch (Err e)
      {
        this.log("Got an error while mapping a document: " + e.toStr + e.traceToStr)
      }
    }

    // Return an empty list (...of lists of lists) if there are no results
    this.output.writeJson((results.size > 0) ? [results,] : [[[,],],])
    this.output.write('\n')
  }

  // Reduce
  private Void reduce(List methodSources, List data)
  {
    results := [,]
    methodSources.each |methodSource|
    {
      try
      {
        Method f := this.compile(methodSource, "reduce").type("Temporary").method("reduce")

        // Unlike javascript reduce functions, fantom functions receive [[key, doc], value] list
        results.add(f.call(data))
      }
      catch (Err e)
      {
        this.log("Got an error while reducing data: " + e.toStr + e.traceToStr)
      }
    }

    this.output.writeJson((results.size > 0) ? [true, results] : [false,])
    this.output.write('\n')
  }

  // Rereduce
  private Void rereduce(List methodSources, List data)
  {
    results := [,]
    methodSources.each |methodSource|
    {
      try
      {
        Method f := this.compile(methodSource, "reduce").type("Temporary").method("reduce")

        results.add(f.call(data, true))
      }
      catch (Err e)
      {
        this.log("Got an error while rereducing data: " + e.toStr + e.traceToStr)
      }
    }

    this.output.writeJson((results.size > 0) ? [true, results] : [false,])
    this.output.write('\n')
  }

  // Compilation
  private Pod compile(Str source, Str methodName := "map")
  {
    // prepare input
    this.compilationCycle += 1
    ci := CompilerInput()
    ci.podName   = "temp${this.compilationCycle}"
    ci.version   = Version("0")
    ci.log.level = LogLevel.silent
    ci.isScript  = true
    ci.srcStr    = "class Temporary { $source }"
    ci.srcStrLoc = Loc("")
    ci.mode      = CompilerInputMode.str
    ci.output    = CompilerOutputMode.transientPod
    ci.summary   = "Temporary pod. That's it."

    // compile the source
    compiler := Compiler(ci)
    CompilerOutput? co := null
    co = compiler.compile

    if (co.transientPod.type("Temporary").method(methodName) == null) throw Err.make("Postcompile error: no \"${methodName}\" method!")
    if (compiler.types[0].methods[-1].isStatic != true) throw Err.make("Postcompile error: not a static method!")
    return co.transientPod
  }

  // Json i/o streams
  private JsonInStream input; JsonOutStream output
  // List to store pods in
  private Pod[] pods
  // Counter to generate different pod names
  private Int compilationCycle
}

