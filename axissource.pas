unit AxisSource;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  { tAxisSource }

  tAxisSource = class
    Count, Capacity: longword;
    Values: array of double;

    constructor Create(InitialCap: longword = 4);
    destructor Destroy; override;

    procedure Add(v: double);
    procedure Clear;
  end;

implementation

{ tAxisSource }

constructor tAxisSource.Create(InitialCap: longword = 4);
begin
  Count:= 0;
  if InitialCap > 4 then
    Capacity:= InitialCap
  else
    Capacity:= 4;
  Setlength(Values, Capacity);
end;

destructor tAxisSource.Destroy;
begin
  setlength(Values, 0);
end;

procedure tAxisSource.Add(v: double);
begin
  inc(Count);
  if Count > Capacity then Capacity += Capacity shr 2;
  setlength(Values, Capacity);
  Values[Count - 1]:= v;
end;

procedure tAxisSource.Clear;
begin
  Count:= 0;
  Capacity:= 4;
  setlength(Values, Capacity);
end;

end.

