//
// Copyright (c) 2010, Ivan Grishulenko
// Licensed under the Academic Free License version 3.0
//
// History:
//   In past     Ivan Grishulenko  Creation
//   2010-10-21  Ivan Grishulenko  Removing unused old code
//

using util
using compiler
using couchdbvs

class Tester
{

  static Void main()
  {
    act
  }

  static Void act()
  {
    try
    {
      echo("working...")
      File fin := File.make(`data/input.txt`)
      File fout := File.make(`data/output.txt`)
      ViewServer vs := ViewServer.make(fin.in, fout.out)
      vs.run
    }
    catch (Err e)
    {
      echo(e.toStr + e.traceToStr)
    }
  }
}
