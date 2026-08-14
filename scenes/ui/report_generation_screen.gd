extends Control
## Écran "rapport de mission" : même chrome tête/pied (header/footer, voir
## desktop.tscn) que le bureau — atteint en remplaçant la scène desktop une
## fois la confirmation validée (voir clue_board_window.gd::ReportConfirmDialog
## et desktop.gd::_on_generate_report_requested), sans retour en arrière
## possible. Contenu du rapport lui-même (ContentLayer, pour l'instant vide)
## à venir dans une prochaine passe.
