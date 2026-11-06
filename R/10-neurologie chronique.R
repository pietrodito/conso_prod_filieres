(
  FIXE_FILIÈRES_IMPAIR
  %>% filter(
      between(dp_3char, "G10", "G37") | between(dr_3char, "G10", "G37")
    | between(dp_3char, "G60", "G73") | between(dr_3char, "G60", "G73")
    | between(dp_3char, "F00", "F03") | between(dr_3char, "F00", "F03")
  )
  %>% select(ident)
  %>% mutate(filière = "Neuro. Chroni., Démences")
) -> IDENT_NEURO_CHRONIQUE

(
  FIXE_FILIÈRES_IMPAIR
  %>% rows_update(IDENT_NEURO_CHRONIQUE, unmatched = "ignore")
  %>% table_temporaire(FIXE_FILIÈRES_PAIR)
)

