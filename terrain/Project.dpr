program Project;

uses
  Forms,
  UnitMain in 'UnitMain.pas' {FormMain},
  GLTypes in 'GLTypes.pas',
  gl_terrainutils in 'gl_terrainutils.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
