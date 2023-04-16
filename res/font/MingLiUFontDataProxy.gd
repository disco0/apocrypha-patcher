tool
class_name MingLiUDynamicFontDataProxy
extends DynamicFontData


# Avoids issue of redistributing fonts by loading font data from Windows system font folder
# when resource initialized. Also just wanted to see if I could do it
#
# https://learn.microsoft.com/en-us/typography/fonts/font-faq
#
# > Can I embed the fonts into a game, application or device I’m developing based on the document
# > font embedding permissions?
#
# No, document font embedding permissions relate to embedding fonts in documents only, not embedding
# fonts in games, apps and devices.
#
# > Can I embed the fonts into a game, application or device I’m developing based on the document
# > font embedding permissions?
#
# No, document font embedding permissions relate to embedding fonts in documents only, not embedding fonts in games, apps and devices.


const MingLiuSystemFontPath := 'C:/Windows/Fonts/mingliub.ttc'


func _init() -> void:
	font_path = MingLiuSystemFontPath
