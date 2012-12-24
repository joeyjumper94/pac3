local L = pace.LanguageString

pace.Fonts = 
{
	"DermaDefault",
	"Default",
	"BudgetLabel",
	"DefaultSmallDropShadow",
	"DefaultBold",
	"TabLarge",
	"DefaultFixedOutline",
	"ChatFont",
	"DefaultFixedDropShadow",
	"UiBold",
}

for i = 1, 5 do
	surface.CreateFont("pac_font_"..i, 
	{
		font = "Tahoma",
		size = 11 + i,
		weight = 50,
		antialias = true,
	})
	table.insert(pace.Fonts, i, "pac_font_"..i)
end

pace.ShadowedFonts = 
{
	["BudgetLabel"] = true,
	["DefaultSmallDropShadow"] = true,
	["TabLarge"] = true,
	["DefaultFixedOutline"] = true,
	["ChatFont"] = true,
	["DefaultFixedDropShadow"] = true,
}


local font_cvar = CreateClientConVar("pac_editor_font", pace.Fonts[1])

function pace.SetFont(fnt)
	pace.CurrentFont = fnt or font_cvar:GetString()
	RunConsoleCommand("pac_editor_font", pace.CurrentFont)
	
	if pace.Editor and pace.Editor:IsValid() then
		pace.CloseEditor()
		timer.Simple(0.1, function()
			pace.OpenEditor()
		end)
	end
end

function pace.AddFontsToMenu(menu)
	local menu = menu:AddSubMenu(L"font")
	menu.GetDeleteSelf = function() return false end
	
	for key, val in pairs(pace.Fonts) do
		menu:AddOption(val, function()
			pace.SetFont(val)
		end)
		
		local pnl = menu.Items and menu.Items[#menu.Items]
		
		if pnl and pnl:IsValid() then
			pnl:SetFont(val)
			if pace.ShadowedFonts[val] then
				pnl:SetTextColor(derma.Color("text_bright", pnl, color_white))
			else
				pnl:SetTextColor(derma.Color("text_dark", pnl, color_black))
			end
		end
	end
end

pace.SetFont()