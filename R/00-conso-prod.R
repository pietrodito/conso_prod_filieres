## Vous devez définir year en exécutant la ligne ci-dessous dans la console :
# year <- 2025
# 
# ou alors, vous devez utiliser le lanceur.R


library(atihdf)
library(tidyverse)
library(dbplyr)
library(readxl)

teradata()

ct(MCO, FIXE, DIAG, UM, ACTE, année = year)
ct(NOMGEN, CORRESP_CODE_COM_GEO_TS_POP)

(
  "data/ght_codegeo.xlsx"
  %>% read_excel()
  %>% select(code_com = CODGEO, ght_codegeo = CODE_GHT)
  %>% copier_vers_teradata(GHT_CODE_COM)
)

(
  "data/raisons_sociales_juridiques_et_géographiques_GPS.xlsx"
  %>% read_excel()
  %>% filter(`Site principal` ==  "x")
  %>% select(finess = finess_pmsi, ght_finess = CODE_GHT)
  %>% copier_vers_teradata(GHT_FINESS)
)

(
  CORRESP_CODE_COM_GEO_TS_POP
  %>% filter(annee == 2025)
  %>% select(code_geo, code_com, pop)
  %>% filtre_HDF(code_geo)
  %>% group_by(code_geo)
  %>% window_order(desc(pop))
  %>% mutate(n = row_number())
  %>% ungroup()
  %>% pivot_wider(names_from = n, values_from = c(code_com, pop))
  %>% select(code_geo, code_com = code_com_1)
  %>% left_join(GHT_CODE_COM)
  %>% select(codegeo = code_geo, ght_codegeo)
) -> GHT_CODEGEO 

(
  FIXE
  %>% nettoie_séjours()
  %>% filter(str_sub(codegeo, end = 2L) %in% codes_départements_hdf
             | # OU LOGIQUE
             str_sub(finess, end = 2L) %in% codes_départements_hdf)
  
  %>% mutate(
    nb_sejours = case_when(
      nbseance > 0 &
        substr(ghm2,1,2) == '28' &
        !(ghm2 %in% c('28Z19Z','28Z20Z','28Z21Z','28Z22Z')) ~ nbseance,
      .default = 1),
    
    PIE = case_when(
      typ_sej == 'B' &
        !(ghm2 %in%  c('28Z03Z', '28Z04Z', '28Z07Z', '28Z08Z', '28Z09Z',
                       '28Z10Z', '28Z11Z', '28Z12Z', '28Z13Z', '28Z17Z',
                       '28Z18Z', '28Z19Z', '28Z20Z', '28Z21Z', '28Z22Z',
                       '28Z23Z',' 28Z23Z', '28Z24Z', '28Z25Z')) ~ 'PIE',
      .default = 'NON PIE'),
    
    age = case_when(
      ! is.na(agejour) & agejour < 28 ~ "Néonat.",
      age < 18 ~ "Pédiatrie",
      age > 75 ~ "Gériatrie",
      .default = "Adulte" ))
  %>% caractérise_hospitalisation()
  %>% caractérise_séjour()
  %>% type_séjour_ajoute_lib("cas")
  %>% type_séjour_ajoute_lib("gp")
  %>% left_join(GHT_CODEGEO)
  %>% left_join(GHT_FINESS)
  %>% select(ident, finess, ght_finess, codegeo, ght_codegeo, age, ghm2, dp, dr,
             sexe, modeentree, modesortie, typ_sej, duree, nbseance, PIE,
             nb_sejours, type_hospitalisation, lib_cas, lib_gp)
  %>% mutate(filière = "Non spécifique")
  %>% mutate(finess =
               if_else( ! str_sub(finess, end = 2L) %in% codes_départements_hdf,
                        "Hors région",
                        finess))
  %>% mutate(ght_finess = if_else(is.na(ght_finess),
                                  "Fuites",
                                  ght_finess))
  %>% mutate(dpt_codegeo = str_sub(end = 2L, codegeo))
  %>% mutate(ght_codegeo = case_when(
    is.na(ght_codegeo) & dpt_codegeo %in% codes_départements_hdf
    ~ "Imprécis",
    is.na(ght_codegeo) & ! dpt_codegeo %in% codes_départements_hdf
    ~  "Attractivité",
    .default =  ght_codegeo))
  %>% mutate(filière = sql("CAST(filière AS VARCHAR(50))"))
  %>% mutate(Année = {{ year }})
  %>% mutate(dp_3char = str_sub(dp, end = 3L))
  %>% mutate(dr_3char = str_sub(dr, end = 3L))
  %>% table_temporaire(FIXE_FILIÈRES_PAIR)
)

##### Détermination filières
##### Utilisation des tables ACTE, DIAG et UM

