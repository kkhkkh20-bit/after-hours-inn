#appendto Dialogue
func Dlg_InnGuest_1(object clonk)
{
 GameCall("InnHideHUD");
 var request = "I need a room for the night. Is one available?";
 if (dlg_target.InnMeal) request = "I only need a meal. What can you offer?";
 MessageBox(request, clonk, dlg_target, nil, false, [["Serve / assign a free room", "Dlg_InnGuest_Serve"], ["Turn away", "Dlg_InnGuest_Refuse"], ["Leave for now", "Dlg_Inn_Close"]]);
 SetDialogueProgress(1);
 return true;
}
func Dlg_InnGuest_Serve(object clonk)
{
 MessageBox(GameCall("InnServe", dlg_target, clonk), clonk, dlg_target);
 StopDialogue(); SetDialogueProgress(1); return true;
}
func Dlg_InnGuest_Refuse(object clonk)
{
 GameCall("InnTurnAway", dlg_target);
 MessageBox("Understood. I will leave.", clonk, dlg_target);
 StopDialogue(); SetDialogueProgress(1); return true;
}
func Dlg_InnStaff_1(object clonk)
{
 GameCall("InnHideHUD");
 MessageBox("I can run reception while you work in the cellar.", clonk, dlg_target, nil, false, [["Hire helper - 30 coins", "Dlg_InnStaff_Hire"], ["Restock 10 meals - 10 coins", "Dlg_InnStaff_Food"], ["Pay today's rent - 120 coins", "Dlg_InnStaff_Rent"], ["How to play", "Dlg_InnStaff_Help"], ["Close", "Dlg_Inn_Close"]]);
 SetDialogueProgress(1); return true;
}
func Dlg_InnStaff_Hire(object clonk) { MessageBox(GameCall("InnHire"), clonk, dlg_target); StopDialogue(); SetDialogueProgress(1); return true; }
func Dlg_InnStaff_Food(object clonk) { MessageBox(GameCall("InnRestock"), clonk, dlg_target); StopDialogue(); SetDialogueProgress(1); return true; }
func Dlg_InnStaff_Rent(object clonk) { MessageBox(GameCall("InnRent"), clonk, dlg_target); StopDialogue(); SetDialogueProgress(1); return true; }
func Dlg_InnStaff_Help(object clonk)
{
 MessageBox("A/D walk, W jump or climb. Mouse selects a tool target; left click uses the selected tool. Shovel digs earth, pickaxe mines rock, hammer opens the ORIGINAL construction preview. Take supplies from a chest with E. Click a traveller to hear their request. Five rooms upstairs, two shafts to the cellar. This is the original PC control scheme; touch controls are not finished.", clonk, dlg_target);
 StopDialogue(); SetDialogueProgress(1); return true;
}

func Dlg_Inn_Close(object clonk) { StopDialogue(); clonk->CloseMenu(); GameCall("InnShowHUD"); return true; }
func Dlg_InnStaff_Closed(object clonk) { GameCall("InnShowHUD"); return true; }
func Dlg_InnGuest_Closed(object clonk) { GameCall("InnShowHUD"); return true; }
