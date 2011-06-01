unit gl_terrainutils;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, OpenGL12, Math, StdCtrls, MMSystem, ExtCtrls, Buttons,
  ComCtrls, GLTools, ToolWin, GLTypes;

type

  TPatchVertex = record
    V: array[0..2] of Single;
    C: array[0..2] of Single;
    T: array[0..1] of Single;
  end;

const

  Div2              = 1.0 / 2.0;
  Div16             = 1.0 / 16.0;
  Div255            = 1.0 / 255.0;

  PatchSize         = 32;
  PatchMax          = 64;               // Must be 1 bigger than PatchSize and should be power of 2.

function TerrainZSmooth(const X, Y: Single): Single;
procedure RenderWorld(const Camera: TGLCamera; const MIPMin, MIPMax: Integer);
procedure handleCameraPos();

var
  PatchMesh         : array[0..PatchMax - 1, 0..PatchMax - 1] of TPatchVertex;
  PatchMIP          : array[-7..7, -7..7] of Integer;
  PatchMIPMin       : Integer;
  PatchMIPMax       : Integer;
  PatchStrip        : array[Word, 0..1] of UINT;
  HeightArray       : array[0..8000] of PByteArray;
  lightLevel        : double;
  MAX_LOD           : double;

implementation

uses UnitMain;

procedure handleCameraPos();
var
  X, Y, X2, Y2      : Single;
  mposx, mposy      : integer;
  nypos             : integer;

  procedure handleAcceleration();
  begin
    with FormMain do
      begin
        Camera.Turn := Camera.Turn + currentTSpeed;
        X := Sin(DegToRad(Camera.Turn));
        Y := -Cos(DegToRad(Camera.Turn));
        X2 := Sin(DegToRad(Camera.Turn - 90));
        Y2 := -Cos(DegToRad(Camera.Turn - 90));
        Camera.X := Camera.X + (X * currentXSpeed) + (X2 * currentYSpeed);
        Camera.Y := Camera.Y + (Y * currentXSpeed) + (Y2 * currentYSpeed);
        if (accelerate > 0) then
          if (currentXSpeed < MAX_SPEED) then currentXSpeed := currentXSpeed + 0.05;
        if (accelerate < 0) then
          if (currentXSpeed > -MAX_SPEED) then currentXSpeed := currentXSpeed - 0.05;
        if (accelerateY > 0) then
          if (currentYSpeed < MAX_SPEED) then currentYSpeed := currentYSpeed + 0.05;
        if (accelerateY < 0) then
          if (currentYSpeed > -MAX_SPEED) then currentYSpeed := currentYSpeed - 0.05;
        if (accelerateT > 0) then
          if (currentTSpeed < 3 * MAX_SPEED) then currentTSpeed := currentTSpeed + 0.05;
        if (accelerateT < 0) then
          if (currentTSpeed > -3 * MAX_SPEED) then currentTSpeed := currentTSpeed - 0.05;
        currentXSpeed := currentXSpeed / 1.1;
        currentTSpeed := currentTSpeed / 1.1;
        currentYSpeed := currentYSpeed / 1.1;
        currentHeight := currentHeight + ((currentHeightTarget - currentHeight) / 10);
      end;
  end;

  procedure handleMouseDrag();
  begin
    with FormMain do
      begin
        if mouseDrag then
          begin
            mposx := (mouseDragPos.X - Mouse.CursorPos.X);
            mposy := (mouseDragPos.Y - Mouse.CursorPos.Y);
            if (1 = 2) then
              begin
                if FrameCount > 0 then
                  begin
                    Camera.Turn := Camera.Turn + (mposx / 3);
                    pitchOffset := (mposy / 10);
                    nypos := Mouse.CursorPos.Y;
                    if (nypos > 50) then nypos := 50;
                    if (nypos < -100) then nypos := -100;
                  end;
                // Screen.Height shr 1
              end;
            currentXSpeed := (-mposy / 10) + currentXSpeed;
            currentYSpeed := (-mposx / 10) + currentYSpeed;
            Screen.Cursor := crNone;
            Mouse.CursorPos := Point(mouseDragPos.X, mouseDragPos.Y);
          end
        else
          screen.Cursor := crHandPoint;
      end;
  end;

begin
  with FormMain do
    begin
      handleAcceleration();
      handleMouseDrag();
      FogDefault.Color.Init(lightLevel / 4, lightLevel / 4, lightLevel / 4, 1);
      FogDefault.Density := 0.000 + (1 / (currentHeight * 8));

      if ViewMode = 0 then
        begin
          Camera.Pitch := pitchOffset + Camera.Pitch + ((TerrainZSmooth(Camera.X - X * 4, Camera.Y - Y * 4) - TerrainZSmooth(Camera.X + X * 4, Camera.Y + Y * 4)) * 5 - Camera.Pitch) * 0.1;
          //Camera.Roll := Camera.Roll + ((TerrainZSmooth(Camera.X + Y * 4, Camera.Y - X * 4) - TerrainZSmooth(Camera.X - Y * 4, Camera.Y + X * 4)) * 5 - Camera.Roll) * 0.1;
          Camera.Z := currentHeight * 1.5 + Camera.Z - (Camera.Z - TerrainZSmooth(Camera.X, Camera.Y) - 2) * 0.5;
        end;
      if ViewMode = 1 then
        begin
          camZOffset := (camZOffset * 25 + (10 + TerrainZSmooth(Camera.X, Camera.Y))) / 26;
          if camZOffset < -4 then camZOffset := -4;
          Camera.Z := currentHeight + camZOffset;
          Camera.Pitch := 30 + currentHeight / 1.5;
          Camera.Roll := 0;
        end;
    end;
end;

function HeightMap(const X, Y: Integer): Byte;
begin
  Result := HeightArray[Y and 255][X and 255];
end;

function TerrainZ(const X, Y: Integer): Single;
begin
  Result := HeightArray[Y and 255][X and 255] * -0.10;
end;

function TerrainZSmooth(const X, Y: Single): Single;
var A, B            : Single;
begin
  A := ((TerrainZ(Trunc(X), Trunc(Y) + 0) * (1 - Frac(X))) + (TerrainZ(Trunc(X) + 1, Trunc(Y) + 0) * Frac(X)));
  B := ((TerrainZ(Trunc(X), Trunc(Y) + 1) * (1 - Frac(X))) + (TerrainZ(Trunc(X) + 1, Trunc(Y) + 1) * Frac(X)));
  Result := (A * (1 - Frac(Y)) + B * Frac(Y));
end;

function LightMap(const X, Y: Integer): Single;
begin
  Result := lightLevel - (Abs(HeightMap(X, Y + 5) + HeightMap(X, Y - 5) * -3) * Div255);
end;

procedure RenderPatchStrips(const LOD: Integer);
var X, Y            : Integer;
begin
  glEnableClientState(GL_COLOR_ARRAY);
  glEnableClientState(GL_VERTEX_ARRAY);
  glEnableClientState(GL_TEXTURE_COORD_ARRAY);

  glColorPointer(3, GL_FLOAT, SizeOf(TPatchVertex), @PatchMesh[0, 0].C);
  glVertexPointer(3, GL_FLOAT, SizeOf(TPatchVertex), @PatchMesh[0, 0].V);
  glTexCoordPointer(2, GL_FLOAT, SizeOf(TPatchVertex), @PatchMesh[0, 0].T);

  for Y := 0 to LOD - 1 do
    begin
      for X := 0 to LOD do
        begin
          PatchStrip[X, 0] := (Y + 0) * PatchMax + X;
          PatchStrip[X, 1] := (Y + 1) * PatchMax + X;
        end;
      glDrawElements(GL_TRIANGLE_STRIP, LOD shl 1 + 2, GL_UNSIGNED_INT, @PatchStrip);
    end;

  glDisableClientState(GL_COLOR_ARRAY);
  glDisableClientState(GL_VERTEX_ARRAY);
  glDisableClientState(GL_TEXTURE_COORD_ARRAY);
end;

procedure StitchPatch(const X, Y: Integer);
var I, M, L, D      : Integer;
begin
  M := PatchMIP[Y, X]; L := PatchSize shr M;
  D := PatchMIP[Y, X + 1] - M; if D > 0 then for I := 0 to L do PatchMesh[I, L] := PatchMesh[I shr D shl D, L];
  D := PatchMIP[Y, X - 1] - M; if D > 0 then for I := 0 to L do PatchMesh[I, 0] := PatchMesh[I shr D shl D, 0];
  D := PatchMIP[Y + 1, X] - M; if D > 0 then for I := 0 to L do PatchMesh[L, I] := PatchMesh[L, I shr D shl D];
  D := PatchMIP[Y - 1, X] - M; if D > 0 then for I := 0 to L do PatchMesh[0, I] := PatchMesh[0, I shr D shl D];
end;

procedure RenderPatch(const MipX, MipY: Integer; const Camera: TGLCamera);
var
  X, Y, XC, YC, WX, WY, TX, TY, LOD, MIP: Integer;
  TrunCameraX, TrunCameraY: Integer;
  FracCameraX, FracCameraY: Single;
begin
  MIP := PatchMIP[MipY, MipX];
  LOD := PatchSize shr MIP;

  XC := MipX * PatchSize - (PatchSize shr 1);
  YC := MipY * PatchSize - (PatchSize shr 1);

  TrunCameraX := Trunc(Camera.X * Div16) * 16;
  TrunCameraY := Trunc(Camera.Y * Div16) * 16;
  FracCameraX := Frac(Camera.X * Div16) * 16;
  FracCameraY := Frac(Camera.Y * Div16) * 16;

  for Y := 0 to LOD do
    begin
      for X := 0 to LOD do
        begin
          WX := X shl MIP + XC;
          WY := Y shl MIP + YC;
          TX := (WX + TrunCameraX) shr MIP shl MIP;
          TY := (WY + TrunCameraY) shr MIP shl MIP;

          with PatchMesh[Y, X] do
            begin
              V[0] := WX - FracCameraX;
              V[1] := TerrainZ(TX, TY) - Camera.Z;
              V[2] := WY - FracCameraY;
              T[0] := TX * 0.01;
              T[1] := TY * 0.01;
              C[0] := LightMap(TX, TY);
              C[1] := C[0];
              C[2] := C[0];
            end;
        end;
    end;
  StitchPatch(MipX, MipY);
  RenderPatchStrips(LOD);
end;

procedure RenderTerrain(const Camera: TGLCamera; const Size, MIPMin, MIPMax: Integer);
var X, Y            : Integer;
begin
  if (PatchMIPMin <> MIPMin) or (PatchMIPMax <> MIPMax) then
    begin
      PatchMIPMin := MIPMin;
      PatchMIPMax := MIPMax;
      for Y := Low(PatchMIP) to High(PatchMIP) do
        begin
          for X := Low(PatchMIP[Y]) to High(PatchMIP[Y]) do
            begin
              PatchMIP[Y, X] := EnsureRange(Round(Hypot(X, Y)), MIPMin, MIPMax);
            end;
        end;
    end;
  for Y := -Size to Size do
    begin
      for X := -Size to Size do
        begin
          RenderPatch(X, Y, Camera);
        end;
    end;
end;

procedure RenderSkyBox(const texFront, texBack, texLeft, texRight, texTop: Integer);
var A, B            : Single;
begin
  A := 0.0015;
  B := 1.0 - A;

  glColor4f(1, 1, 1, 1);

  glPushMatrix;
  glScalef(170 * 10, 120 * 10, 170 * 10);

  glBindTexture(GL_TEXTURE_2D, texFront);
  glBegin(GL_QUADS);
  glTexCoord2f(A, A); glVertex3d(-1, -1, -1);
  glTexCoord2f(B, A); glVertex3d(1, -1, -1);
  glTexCoord2f(B, B); glVertex3d(1, 1, -1);
  glTexCoord2f(A, B); glVertex3d(-1, 1, -1);
  glEnd;

  glBindTexture(GL_TEXTURE_2D, texLeft);
  glBegin(GL_QUADS);
  glTexCoord2f(A, A); glVertex3f(-1, -1, 1);
  glTexCoord2f(B, A); glVertex3f(-1, -1, -1);
  glTexCoord2f(B, B); glVertex3f(-1, 1, -1);
  glTexCoord2f(A, B); glVertex3f(-1, 1, 1);
  glEnd;

  glBindTexture(GL_TEXTURE_2D, texRight);
  glBegin(GL_QUADS);
  glTexCoord2f(A, A); glVertex3f(1, -1, -1);
  glTexCoord2f(B, A); glVertex3f(1, -1, 1);
  glTexCoord2f(B, B); glVertex3f(1, 1, 1);
  glTexCoord2f(A, B); glVertex3f(1, 1, -1);
  glEnd;

  glBindTexture(GL_TEXTURE_2D, texTop);
  glBegin(GL_QUADS);
  glTexCoord2f(A, A); glVertex3f(-1, 1, -1);
  glTexCoord2f(B, A); glVertex3f(1, 1, -1);
  glTexCoord2f(B, B); glVertex3f(1, 1, 1);
  glTexCoord2f(A, B); glVertex3f(-1, 1, 1);
  glEnd;

  glBindTexture(GL_TEXTURE_2D, texBack);
  glBegin(GL_QUADS);
  glTexCoord2f(A, A); glVertex3f(1, -1, 1);
  glTexCoord2f(B, A); glVertex3f(-1, -1, 1);
  glTexCoord2f(B, B); glVertex3f(-1, 1, 1);
  glTexCoord2f(A, B); glVertex3f(1, 1, 1);
  glEnd;
  glPopMatrix
end;

procedure RenderWater(const Camera: TGLCamera; const Level: Single);
  procedure WaterVertex(const X, Y, Z: Single; const Camera: TGLCamera);
  begin
    glTexCoord2f((X + Camera.X) * 0.02, (Z + Camera.Y) * 0.02);
    glVertex3f(X, Y, Z);
  end;
begin
  glPushAttrib(GL_ENABLE_BIT);

  glEnable(GL_BLEND);
  glDisable(GL_CULL_FACE);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA); // As recommended by the OpenGL docs.

  glColor4f(1, 1, 1, 0.4);

  glBindTexture(GL_TEXTURE_2D, FormMain.texWater[(timeGetTime shr 6) and 63]);

  glBegin(GL_QUADS);
  WaterVertex(200, Level - Camera.Z - 0.2, -200, Camera);
  WaterVertex(-200, Level - Camera.Z - 0.2, -200, Camera);
  WaterVertex(-200, Level - Camera.Z - 0.2, 200, Camera);
  WaterVertex(200, Level - Camera.Z - 0.2, 200, Camera);
  glEnd;

  glEnable(GL_CULL_FACE);
  glColor4f(lightLevel / 8, lightLevel / 8, lightLevel / 5, (1 / lightLevel));

  glBindTexture(GL_TEXTURE_2D, FormMain.texSkyTop);
  glBegin(GL_QUADS);
  glTexCoord2f(0, 0); glVertex3f(200, Level - Camera.Z, -200);
  glTexCoord2f(1, 0); glVertex3f(-200, Level - Camera.Z, -200);
  glTexCoord2f(1, 1); glVertex3f(-200, Level - Camera.Z, 200);
  glTexCoord2f(0, 1); glVertex3f(200, Level - Camera.Z, 200);
  glEnd;

  glPopAttrib;
end;

procedure RenderWorld(const Camera: TGLCamera; const MIPMin, MIPMax: Integer);
var
  WaterLevel        : Single;
begin
  WaterLevel := -15 + Cos(DegToRad(timeGetTime shr 6)) * 0.3;

  glEnable(GL_FOG);
  glFogi(GL_FOG_MODE, GL_EXP);

  glPushMatrix;
  glLoadIdentity;
  glRotatef(Camera.Roll, 0, 0, 1);
  glRotatef(Camera.Pitch, 1, 0, 0);
  glRotatef(Camera.Turn, 0, 1, 0);

  if WaterLevel > Camera.Z then
    begin
      glFogfv(GL_FOG_COLOR, @FormMain.FogWater.Color);
      glFogf(GL_FOG_DENSITY, FormMain.FogWater.Density);
    end
  else
    begin
      glFogfv(GL_FOG_COLOR, @FormMain.FogDefault.Color);
      glFogf(GL_FOG_DENSITY, FormMain.FogDefault.Density);
      glFogf(GL_FOG_MODE, GL_EXP2);
    end;

  glBindTexture(GL_TEXTURE_2D, FormMain.texSnow);

  RenderTerrain(Camera, ROund(MAX_LOD), MIPMin, MIPMax);

  RenderSkyBox(
    FormMain.texSkyFront,
    FormMain.texSkyBack,
    FormMain.texSkyLeft,
    FormMain.texSkyRight,
    FormMain.texSkyTop);

  glDisable(GL_FOG);

  RenderWater(Camera, WaterLevel);

  glPopMatrix;
end;

end.

