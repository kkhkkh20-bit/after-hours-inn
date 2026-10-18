#appendto Clonk
func MouseSelection(int plr)
{
 if (this.InnStaff || this.InnState)
 {
  var dlg = Dialogue->FindByTarget(this);
  if (dlg) return dlg->Interact(GetCursor(plr));
 }
 return _inherited(plr, ...);
}
