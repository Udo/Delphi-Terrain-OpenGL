//------------------------------------------------------------------------
//
// Author      : Jan Horn
// Email       : jhorn@global.co.za
// Website     : http://home.global.co.za/~jhorn
// Date        : 7 October 2001
// Version     : 1.0
// Description : Quake 3 Model Loader (MD3 Loader) 
//
//------------------------------------------------------------------------
unit model;

interface

uses
  Windows, SysUtils, OpenGL, Textures;

type
  TMD3Header = Record
    ID : Array[1..4] of Char;               // id = IDP3
    Version       : Integer;                // Version = 15
    Filename      : Array[1..68] of Char;
    numBoneFrames : Integer;
    numTags       : Integer;
    numMeshes     : Integer;
    numMaxSkins   : Integer;
    headerLength  : Integer;
    TagStart      : Integer;
    TagEnd        : Integer;
    FileSize      : Integer;
  end;

  TBoneFrame = Record
    mins : Array[0..2] of glFloat;
    maxs : Array[0..2] of glFloat;
    Position : Array[0..2] of glFloat;
    Scale    : glFloat;
    Creator  : Array[1..16] of Char;
  end;

  TAnim = Record
    FirstFrame     : Integer;
    numFrames      : Integer;
    LoopingFrames  : Integer;
    FPS            : Integer;
  end;

  TRotationMatrix = Array[0..2, 0..2] of glFloat;
  TVector = Array[0..2] of glFloat;
  TTag = Record
    Name     : Array[1..64] of Char;
    Position : TVector;
    Rotation : TRotationMatrix;
  end;

  TTriangle = Record
    Vertex : Array[0..2] of Integer;
  end;

  TTexCoord = Record
    Coord : Array[0..1] of glFloat;
  end;

  TVertex = Record
    Vertex : Array[0..2] of Smallint;
    Normal : Array[0..1] of Byte;
  end;

  TMeshHeader = Record
    ID   : Array[1..4] of Char;
    Name : Array[1..68] of Char;
    numMeshFrames : Integer;
    numSkins     : Integer;
    numVertexes  : Integer;
    numTriangles : Integer;
    triStart     : Integer;
    headerSize   : Integer;
    TexVectorStart : Integer;
    VertexStart  : Integer;
    MeshSize     : Integer;
  end;

  TMesh = Record
    MeshHeader : TMeshHeader;
    Skins      : Array of Array[1..68] of Char;
    Triangle   : Array of TTriangle;
    TexCoord   : Array of TTexCoord;
    Vertex     : Array of TVertex;
    Texture    : glUint;
    SetTexture : Boolean;
  end;

  PMD3Model = ^TMD3Model;
  TMD3Model = object
    frame      : Integer;      // Current frame to draw
    startFrame : Integer;
    endFrame   : Integer;
    nextFrame  : Integer;      // Next frame to draw
    FPS        : Integer;
    Poll       : glFloat;      // Interpolation Time;
    LastUpdate : glFloat;      // last draw
    TexNr      : Integer;      // using for LoadSkin (*.skin)
    TexInf     : Array[0..99] of Integer;   // using for LoadSkin (*.skin)
    md3name    : String;
    Header     : TMD3header;
    BoneFrames : Array of TBoneFrame;
    Tags       : Array of TTag;
    Meshes     : Array of TMesh;
    Links      : Array of PMD3Model;
    procedure LoadModel(filename : String);
    procedure DrawModelInt(const currentFrame, nexFrame : Integer; const pol: Real);
    procedure DrawModel;
    procedure DrawSkeleton(var Mdl : TMD3Model);
    procedure UpdateFrame(time : glFLoat);
    procedure LinkModel(tagname : String; var MD3Model : TMD3Model);
    procedure LoadSkin(Imagepath, filename : String);
  end;

  Q3Player = Object
    Lower, Upper, Head : TMD3Model;
    anim : Array[0..25] of TAnim;
    animLower, animUpper : Integer;
    procedure LoadAnim(filename : String);
    procedure LoadPlayer(path, skin : String);
    procedure SetAnim(ani : Integer);
    procedure Draw(time : glFLoat);
  end;

const BOTH_DEATH1 = 0;
      BOTH_DEAD1  = 1;
      BOTH_DEATH2 = 2;
      BOTH_DEAD2  = 3;
      BOTH_DEATH3 = 4;
      BOTH_DEAD3  = 5;

      TORSO_GESTURE = 6;
      TORSO_ATTACK  = 7;
      TORSO_ATTACK2 = 8;
      TORSO_DROP    = 9;
      TORSO_RAISE   = 10;
      TORSO_STAND   = 11;
      TORSO_STAND2  = 12;

      LEGS_WALKCR   = 13;
      LEGS_WALK     = 14;
      LEGS_RUN      = 15;
      LEGS_BACK     = 16;
      LEGS_SWIM     = 17;
      LEGS_JUMP     = 18;
      LEGS_LAND     = 19;
      LEGS_JUMPB    = 20;
      LEGS_LANDB    = 21;
      LEGS_IDLE     = 22;
      LEGS_IDLECR   = 23;
      LEGS_TURN     = 24;

      MAX_ANIMATIONS = 25;


var anorms : Array[0..255, 0..255, 0..2] of Real;

function CharArrToStr(const C : Array of Char) : String;

implementation

procedure glBindTexture(target: GLenum; texture: GLuint); stdcall; external opengl32;


function ArcTan2(Y, X: Extended): Extended;
asm
  FLD     Y
  FLD     X
  FPATAN
  FWAIT
end;

function ArcCos(X: Extended): Extended;
begin
  Result := ArcTan2(Sqrt(1 - X*X), X);
end;


{---------------------------------------------------------}
{--- Converts an array of characters to a string       ---}
{---------------------------------------------------------}
function CharArrToStr(const C : Array of Char) : String;
var I : Integer;
begin
  // convert the array of characters to a String
  I :=0;
  result :='';
  while C[i] <> #0 do
  begin
    result := result + C[I];
    Inc(I);
  end;
end;


{---------------------------------------------------------}
{--- Create a lookup table of normals. Faster this way ---}
{---------------------------------------------------------}
procedure InitNormals;
var I, J : Integer;
    alpha, beta : Real;
begin
  for I :=0 to 255 do
  begin
    for J :=0 to 255 do
    begin
      alpha :=2*I*pi/255;
      beta :=2*j*pi/255;
      anorms[i][j][0] := cos(beta) * sin(alpha);
      anorms[i][j][1] := sin(beta) * sin(alpha);
      anorms[i][j][2] := cos(alpha);
    end;
  end;
end;


{  TMD3Model  }

{---------------------------------------------------------}
{---  Draws a model                                    ---}
{---------------------------------------------------------}
procedure TMD3Model.DrawModel;
begin
  DrawModelInt(frame, nextframe, poll);
end;


{---------------------------------------------------------}
{---  Draw the model using interpolation               ---}
{---------------------------------------------------------}
procedure TMD3Model.DrawModelInt(const currentFrame, nexFrame : Integer; const pol: Real);
var i, j, k : Integer;
    triangleNum, currentMesh, currentOffsetVertex,
    currentVertex, nextCurrentOffsetVertex : Integer;
    normU, normV : Integer;
    s, t : glFloat;
    v, n : Array[0..2] of glFloat;
    nextV, nextN : Array[0..2] of glFloat;
begin
  For k :=0 to header.numMeshes-1 do
  begin
    currentMesh :=k;
    currentOffsetVertex :=currentFrame * meshes[currentMesh].MeshHeader.numVertexes;
    // interpolation
    nextCurrentOffsetVertex := nexFrame * meshes[currentMesh].MeshHeader.numVertexes;

    TriangleNum := Meshes[currentMesh].MeshHeader.numTriangles;

    if meshes[k].settexture then
      glBindTexture(GL_TEXTURE_2D, meshes[k].texture);
    for I :=0 to TriangleNum-1 do
    begin
      glBegin(GL_TRIANGLES);
      for J :=0 to 2 do
      begin
        currentVertex := Meshes[currentMesh].Triangle[i].vertex[j];

        v[0] :=meshes[currentMesh].vertex[currentOffsetVertex + currentVertex].Vertex[0] / 64;
        v[1] :=meshes[currentMesh].vertex[currentOffsetVertex + currentVertex].Vertex[1] / 64;
        v[2] :=meshes[currentMesh].vertex[currentOffsetVertex + currentVertex].Vertex[2] / 64;

        nextv[0] :=meshes[currentMesh].vertex[nextCurrentOffsetVertex + currentVertex].Vertex[0] / 64;
        nextv[1] :=meshes[currentMesh].vertex[nextCurrentOffsetVertex + currentVertex].Vertex[1] / 64;
        nextv[2] :=meshes[currentMesh].vertex[nextCurrentOffsetVertex + currentVertex].Vertex[2] / 64;

	normU := meshes[currentMesh].vertex[currentOffsetVertex + currentVertex].Normal[0];
	normV := meshes[currentMesh].vertex[currentOffsetVertex + currentVertex].Normal[1];

	n[0] :=aNorms[normU, normV, 0];
	n[1] :=aNorms[normU, normV, 1];
	n[2] :=aNorms[normU, normV, 2];

        // interpolated U, V and N
        normU := meshes[currentMesh].vertex[nextCurrentOffsetVertex + currentVertex].Normal[0];
        normV := meshes[currentMesh].vertex[nextCurrentOffsetVertex + currentVertex].Normal[1];

        nextN[0] := anorms[normU, normV, 0];
        nextN[1] := anorms[normU, normV, 1];
        nextN[2] := anorms[normU, normV, 2];

	s :=meshes[currentMesh].TexCoord[currentVertex].Coord[0];
	t :=meshes[currentMesh].TexCoord[currentVertex].Coord[1];

	glTexCoord2f(s, 1-t);

        // interpolation
        glNormal3f(n[0] + pol * (nextN[0] - n[0]), n[1] + pol * (nextN[1] - n[1]), n[2] + pol * (nextN[2] - n[2]));
        glVertex3f(v[0] + pol * (nextV[0] - v[0]), v[1] + pol * (nextV[1] - v[1]), v[2] + pol * (nextV[2] - v[2]));
      end;
      glEnd;
    end;
  end;
end;


{---------------------------------------------------------}
{--- Links a model to a tag. (head is linked to torso) ---}
{---------------------------------------------------------}
procedure TMD3Model.LinkModel(tagname: String; var MD3Model: TMD3Model);
var I : Integer;
begin
  for I :=0 to Header.numTags-1 do
  begin
    if CharArrToStr(tags[i].Name) = tagname then
    begin
      Links[i] :=@MD3Model;
      exit;
    end;
  end;
end;


{---------------------------------------------------------}
{---  Loads a model from a .MDL files                  ---}
{---  Result 1 = OK, -1 = no file, -2 = Bad header     ---}
{---------------------------------------------------------}
procedure TMD3Model.LoadModel(filename: String);
var F : File;
    I : Integer;
    MeshOffset : Integer;
begin
  if FileExists(filename) = FALSE then
    exit;

  AssignFile(F, filename);
  Reset(F,1);

  // copy name
  MD3Name :=Filename;

  // read header
  BlockRead(F, Header, Sizeof(Header));
  if (Uppercase(Header.ID) <> 'IDP3') OR (Header.Version <> 15) then
  begin
    CloseFile(F);
    exit;
  end;

  // read boneframes
  SetLength(BoneFrames, Header.numBoneFrames);
  BlockRead(F, BoneFrames[0], Header.numBoneFrames*sizeof(TBoneFrame));

  // read tags
  SetLength(Tags, Header.numBoneFrames * Header.numTags);
  BlockRead(F, Tags[0], Header.numBoneFrames*Header.numTags*sizeof(TTag));

  // init links
  SetLength(Links, Header.numTags);
  for I :=0 to Header.NumTags-1 do
    Links[I] :=nil;

  // read meshes
  SetLength(Meshes, Header.numMeshes);
  MeshOffset := FilePos(F);

  For I :=0 to Header.numMeshes-1 do
  begin
    Seek(F, MeshOffset);
    BlockRead(F, Meshes[I].MeshHeader, sizeOf(TMeshHeader));

    // Load the Skins
    SetLength(Meshes[I].Skins, Meshes[I].MeshHeader.numSkins);
    BlockRead(F, Meshes[I].Skins[0], 68 * Meshes[I].MeshHeader.numSkins);

    // Triangles
    Seek(F, MeshOffset + Meshes[I].MeshHeader.triStart);
    SetLength(Meshes[I].Triangle, Meshes[I].MeshHeader.numTriangles);
    BlockRead(F, Meshes[I].Triangle[0], sizeOf(TTriangle)*Meshes[I].MeshHeader.numTriangles);

    // Texture Coordiantes
    Seek(F, MeshOffset + Meshes[I].MeshHeader.TexVectorStart);
    SetLength(Meshes[I].TexCoord, Meshes[I].MeshHeader.numVertexes);
    BlockRead(F, Meshes[I].TexCoord[0], sizeOf(TTexCoord)*Meshes[I].MeshHeader.numVertexes);

    // Vertices
    Seek(F, MeshOffset + Meshes[I].MeshHeader.VertexStart);
    SetLength(Meshes[I].Vertex, Meshes[I].MeshHeader.numVertexes * Meshes[I].MeshHeader.numMeshFrames);
    BlockRead(F, Meshes[I].Vertex[0], sizeOf(TVertex)*Meshes[I].MeshHeader.numVertexes * Meshes[I].MeshHeader.numMeshFrames);

    MeshOffset :=MeshOffset + Meshes[I].MeshHeader.MeshSize;
  end;

  CloseFile(F);

  // set the start, end frame
  Header.numBoneFrames :=Header.numBoneFrames - 1;
  startFrame := 0;
  endFrame := Header.numBoneFrames;
end;


{-------------------------------------------------------------}
{--- Draws the model and other models linked to this model ---}
{-------------------------------------------------------------}
procedure TMD3Model.DrawSkeleton(var Mdl : TMD3Model);
var I    : Integer;
    pMdl : PMD3Model;
    m    : Array[0..15] of glFloat;
    Rotation : TRotationMatrix;
    Position : TVector;
begin
  Mdl.DrawModel;
  for I :=0 to Mdl.Header.numTags-1 do
  begin
    pMdl :=Mdl.Links[i];
    if pMdl <> nil then
    begin
      Position :=Mdl.tags[Mdl.frame * Mdl.Header.numTags + i].Position;
      Rotation :=Mdl.Tags[Mdl.Frame * Mdl.Header.numTags + i].Rotation;

      m[0] := Rotation[0, 0];
      m[1] := Rotation[0, 1];
      m[2] := Rotation[0, 2];
      m[3] := 0;
      m[4] := Rotation[1, 0];
      m[5] := Rotation[1, 1];
      m[6] := Rotation[1, 2];
      m[7] := 0;
      m[8] := Rotation[2, 0];
      m[9] := Rotation[2, 1];
      m[10]:= Rotation[2, 2];
      m[11]:= 0;
      m[12] := position[0];
      m[13] := position[1];
      m[14] := position[2];
      m[15] := 1;

      glPushMatrix();
      glMultMatrixf(@m);
      DrawSkeleton(pMdl^);
      glPopMatrix();
    end;
  end;
end;


{---------------------------------------------------------}
{--- Loads the skins for the model from the .skin file ---}
{---------------------------------------------------------}
procedure TMD3Model.LoadSkin(Imagepath, filename : String);
var F : TextFile;
    I : Integer;
    S : String;
    MeshName, ImageName : String;
begin
  if FileExists(Imagepath + filename) then
  begin
    AssignFile(F,Imagepath + filename);
    Reset(F);
    while EOF(F) = FALSE do
    begin
      Readln(F, S);
      if Length(S) > 1 then
      begin
        if Pos(',', S)+1 < Length(S) then   // there must be something after the comma
        begin
          MeshName :=Copy(S, 1, Pos(',', S)-1);
          if Copy(MeshName, 1, 4) <> 'tag_' then   // tags dont have skins
          begin
            ImageName :=Copy(S, Pos(',', S)+1, Length(S));     // get the full image and path name
            ImageName :=StrRScan(PChar(S), '/');               // get name from last / (i.e only filename)
            ImageName :=Copy(ImageName, 2, Length(ImageName)); // lose the starting /

            // if its a TGA or JPG, then load the skin
            if (pos('.JPG', UpperCase(ImageName)) > 0) OR (pos('.TGA', UpperCase(ImageName)) > 0) then
            begin
              // Find the right mesh item to assign the skin to
              for I :=0 to header.numMeshes-1 do
              begin
                // check it the two names are the same
                if UpperCase(CharArrToStr(meshes[i].MeshHeader.Name)) = Uppercase(meshname) then
                begin
                  LoadTexture(ImagePath + ImageName, meshes[i].Texture, FALSE);
                  meshes[i].SetTexture :=TRUE;
                end;
              end;
            end;
          end;
        end;
      end;
    end;
    CloseFile(F);
  end;
end;


{---------------------------------------------------------}
{---  Updates the active frame for the model           ---}
{---------------------------------------------------------}
procedure TMD3Model.UpdateFrame(Time : glFLoat);
begin
  Poll :=(Time - LastUpdate);
  if Poll > 1/FPS then
  begin
    frame :=NextFrame;
    Inc(NextFrame);
    if NextFrame > EndFrame then
       NextFrame :=StartFrame;
    LastUpdate :=Time;
  end;
end;


{---  Q3Player  ---}


{---------------------------------------------------------}
{---  Draws the models associated with the Players     ---}
{---------------------------------------------------------}
procedure Q3Player.Draw(time : glFLoat);
begin
  Lower.UpdateFrame(time);
  Upper.UpdateFrame(time);
  Head.UpdateFrame(time);
  Lower.DrawSkeleton(Lower);
end;


{---------------------------------------------------------}
{---  Loads animation for the player. (animation.cfg)  ---}
{---------------------------------------------------------}
procedure Q3Player.LoadAnim(filename: String);
var F : Text;
    S : String;
    I, P, skip : Integer;
begin
  if FileExists(filename) = FALSE then
    exit;

  AssignFile(F, filename);
  Reset(F);

  I :=0;
  while EOF(F) = false do
  begin
    Readln(F, S);
    if Pos('sex', S) > 0 then
    else if Pos('headoffset', S) > 0 then
    else if Pos('footsteps', S) > 0 then
    else if (S <> '') AND (Pos('//', S) > 5) then
    begin
      // Extract the values of FirstFrame, numFrames, LoopingFrames, FPS from the String
      P :=Pos(#9, S);
      Anim[i].FirstFrame :=StrToInt(Copy(S, 1, P-1));
      S :=Copy(S, P+1, Length(S));

      P :=Pos(#9, S);
      Anim[i].numFrames :=StrToInt(Copy(S, 1, P-1));
      S :=Copy(S, P+1, Length(S));

      P :=Pos(#9, S);
      Anim[i].loopingFrames :=StrToInt(Copy(S, 1, P-1));
      S :=Copy(S, P+1, Length(S));

      P :=Pos(#9, S);
      if P < 0 then P :=Length(S)+1;
      Anim[i].FPS :=StrToInt(Copy(S, 1, P-1));

      Inc(I);
    end;
  end;
  CloseFile(F);

  skip := anim[LEGS_WALKCR].firstFrame - anim[TORSO_GESTURE].firstFrame;
  for I :=LEGS_WALKCR to MAX_ANIMATIONS do
    Anim[I].firstFrame := Anim[I].firstFrame - skip;

  for I :=0 to MAX_ANIMATIONS do
    if Anim[I].numFrames > 0 then
      Anim[I].numFrames :=Anim[I].numFrames - 1;

end;


{---------------------------------------------------------}
{---  Sets the new animation sequence for the player   ---}
{---------------------------------------------------------}
procedure Q3Player.SetAnim(ani : Integer);
begin
  if ani in [0..5] then
  begin
    Lower.FPS :=anim[ani].FPS;
    Upper.FPS :=anim[ani].FPS;

    Lower.StartFrame :=anim[ani].FirstFrame;
    Upper.StartFrame :=anim[ani].FirstFrame;

    Lower.EndFrame :=anim[ani].FirstFrame + anim[ani].numFrames;
    Upper.EndFrame :=anim[ani].FirstFrame + anim[ani].numFrames;

    animLower :=ani;
    animUpper :=ani;
  end
  else if ani in [6..12] then
  begin
    Upper.FPS :=anim[ani].FPS;
    Upper.NextFrame :=anim[ani].FirstFrame;
    Upper.StartFrame :=anim[ani].FirstFrame;
    Upper.EndFrame :=anim[ani].FirstFrame + anim[ani].numFrames;

    animUpper :=ani;
  end
  else if ani in [13..24] then
  begin
    Lower.FPS :=anim[ani].FPS;
    Lower.NextFrame :=anim[ani].FirstFrame;
    Lower.StartFrame :=anim[ani].FirstFrame;
    Lower.EndFrame :=anim[ani].FirstFrame + anim[ani].numFrames;

    animLower :=ani;
  end
end;


{---------------------------------------------------------}
{---  Loads a player model, skin and snimations        ---}
{---------------------------------------------------------}
procedure Q3Player.LoadPlayer(path, skin: String);
begin
  // Pre-calculate the normals
  if aNorms[0,0,2] <> 1 then
    InitNormals;

  Lower.LoadModel(path + 'lower.md3');
  Upper.LoadModel(path + 'upper.md3');
  Head.LoadModel(path + 'head.md3');

  Lower.LoadSkin(path, 'lower_' + skin + '.skin');
  Upper.LoadSkin(path, 'upper_' + skin + '.skin');
  Head.LoadSkin(path, 'head_' + skin + '.skin');

  LoadAnim(path + 'animation.cfg');

  Lower.startframe :=0;    Lower.EndFrame :=0;
  Upper.startframe :=0;    Upper.EndFrame :=0;
  Head.startframe  :=0;    Head.EndFrame  :=0;

  SetAnim(TORSO_STAND);
  SetAnim(LEGS_WALK);

  Lower.LinkModel('tag_torso', Upper);
  Upper.LinkModel('tag_head', Head);
end;


end.


