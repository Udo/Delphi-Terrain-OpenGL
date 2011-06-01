unit GLTypes;

interface

type

  TGLColor = object
    R, G, B, A: Single;

    procedure Init(const AR, AG, AB, AA: Single);
  end;

  TGLCamera = object
    Roll, Turn, Pitch: Single;
    X, Y, Z: Single;
  end;

  TGLFog = object
    Color: TGLColor;
    Density: Single;
  end;

implementation

procedure TGLColor.Init(const AR, AG, AB, AA: Single);
begin
  R := AR;
  G := AG;
  B := AB;
  A := AA;
end;

end.
