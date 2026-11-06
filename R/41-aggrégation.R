((
  FIXE_FILIÈRES_PAIR
  %>% count(Année, finess, ght_finess, ght_codegeo, age, PIE,
            nb_sejours, type_hospitalisation, lib_cas, lib_gp, filière)
  %>% collect()
) -> Données_réelles)

(
  Données_réelles
  %>% write_csv("out/filières_GHT_{year}.csv" %>% glue)
)




# ==============================================================================
# # 1. FONCTION DE RECHERCHE DU SEUIL ET DE TRANSFORMATION
# # ==============================================================================
# calculer_transformation_ATIH <- function(v_all, marge_securite_pct = 0.5, seed = 2026) {
#   set.seed(seed)
#   
#   # Référence ATIH : probabilité d'être un 1 quand on lit "<11"
#   prob_ATIH <- mean(v_all[v_all < 11] == 1) * 100
#   
#   for (S in 11:30) {
#     idx_sub <- which(v_all < S)
#     v_sub   <- v_all[idx_sub]
#     N_sub   <- length(v_sub)
#     N_1     <- sum(v_sub == 1)
#     N_vrais_S <- sum(v_all == S)
#     
#     # Nombre de S à générer pour conserver exactement le total des séjours
#     E_nb_S_generes <- (sum(v_sub) - N_sub) / (S - 1)
#     
#     # Probabilité optimale de transformer un vrai 1 en S
#     p_1_optimal <- E_nb_S_generes / (N_sub + N_vrais_S)
#     
#     # Pente pour les valeurs de 2 à S-1 afin de conserver l'espérance du total
#     S_restants_a_generer <- E_nb_S_generes - (N_1 * p_1_optimal)
#     v_autres <- v_sub[v_sub > 1]
#     facteur_pente <- S_restants_a_generer / sum(v_autres - 1)
#     
#     # Probabilité de devenir S pour chaque ligne < S
#     prob_devenir_S <- ifelse(v_sub == 1, p_1_optimal, facteur_pente * (v_sub - 1))
#     
#     # Si les probabilités sortent de [0, 1], le seuil S n'est pas valide
#     if (any(prob_devenir_S < 0) || any(prob_devenir_S > 1)) next
#     
#     # Tirage aléatoire (1 ou S)
#     tirage_S <- rbinom(N_sub, size = 1, prob = prob_devenir_S)
#     v_trans  <- v_all
#     v_trans[idx_sub] <- ifelse(tirage_S == 1, as.integer(S), 1L)
#     
#     # Vérification des probabilités à posteriori
#     prob_vrai1_sachant_1 <- mean(v_all[v_trans == 1] == 1) * 100
#     prob_vrai1_sachant_S <- mean(v_all[v_trans == S] == 1) * 100
#     
#     # Validation si les DEUX probabilités sont inférieures à la norme ATIH (avec marge)
#     if (prob_vrai1_sachant_1 < (prob_ATIH - marge_securite_pct) && 
#         prob_vrai1_sachant_S < (prob_ATIH - marge_securite_pct)) {
#       
#       return(list(
#         seuil_S        = as.integer(S),
#         p_1_optimal    = p_1_optimal,
#         facteur_pente  = facteur_pente,
#         vecteur_masque = v_trans
#       ))
#     }
#   }
#   stop("Aucun seuil S valide trouvé entre 11 et 30.")
# }
# 
# # ==============================================================================
# # 2. APPLICATION POUR CRÉER "Données_non_identifiantes"
# # ==============================================================================
# 
# # Étape A : Calcul des paramètres optimaux sur la colonne n de Données_réelles
# res_opt <- calculer_transformation_ATIH(Données_réelles$n, marge_securite_pct = 0.5, seed = 2026)
# 
# # Étape B : Création de la table finale "Données_non_identifiantes"
# # (On utilise directement le seuil S et les probabilités calculées dans un pipeline dplyr)
# set.seed(2026) # Même graine pour garantir exactement le tirage validé
# Données_non_identifiantes <- Données_réelles |>
#   ungroup() |>
#   mutate(
#     n = if_else(
#       n < res_opt$seuil_S,
#       if_else(
#         rbinom(
#           n = n(), 
#           size = 1, 
#           prob = if_else(n == 1, res_opt$p_1_optimal,
#                          pmin(1, pmax(0, res_opt$facteur_pente * (n - 1))))
#         ) == 1,
#         res_opt$seuil_S,
#         1L
#       ),
#       as.integer(n)
#     )
#   )
# 
# # ==============================================================================
# # 3. AUDIT DE CONTRÔLE SUR "Données_non_identifiantes"
# # ==============================================================================
# verif <- tibble(
#   reel   = Données_réelles$n,
#   masque = Données_non_identifiantes$n
# )
# 
# (prob_ATIH         <- mean(verif$reel[verif$reel < 11] == 1) * 100)
# (prob_Notre_1      <- mean(verif$reel[verif$masque == 1] == 1) * 100)
# (prob_Notre_S      <- mean(verif$reel[verif$masque == res_opt$seuil_S] == 1) * 100)
# 
# cat(sprintf("✅ Seuil S appliqué dans Données_non_identifiantes : S = %d\n", res_opt$seuil_S))
# cat(sprintf("   (Probabilité appliquée aux vrais 1 de devenir %d : %.2f%%)\n\n", 
#             res_opt$seuil_S, res_opt$p_1_optimal * 100))
# 
# cat(sprintf("🎯 Référence ATIH (P(Vrai 1 | '<11'))          : %.2f%%\n", prob_ATIH))
# cat(sprintf("🛡️ Notre fichier  (P(Vrai 1 | on lit 1))       : %.2f%%  -> %s\n", 
#             prob_Notre_1, ifelse(prob_Notre_1 < prob_ATIH, "BATTU ✅", "ÉCHEC ❌")))
# cat(sprintf("🛡️ Notre fichier  (P(Vrai 1 | on lit %d))      : %.2f%%  -> %s\n", 
#             res_opt$seuil_S, prob_Notre_S, ifelse(prob_Notre_S < prob_ATIH, "BATTU ✅", "ÉCHEC ❌")))
# cat(sprintf("📊 Total des séjours (Avant : %d | Après : %d)\n", 
#             sum(verif$reel), sum(verif$masque)))
# 
# test_réelles_vs_non_identifiantes <- function() {
#   
#   helper <- function(df) {
#     (
#       df
#       %>% group_by(Année, finess, ght_finess, ght_codegeo, age, PIE,
#                    nb_sejours, type_hospitalisation, lib_cas, lib_gp, filière)
#       %>% summarise(across(n, sum))
#     )
#   }
#   
#   (
#     inner_join(
#       helper(Données_réelles) %>% rename(Réelles = n),
#       helper(Données_non_identifiantes) %>% rename(Imputation = n))
#     %>% mutate(Écart = abs((Imputation / Réelles) - 1 ))
#     %>% arrange(desc(Écart))
#     %>% filter(Écart < 2)
#   ) %>% print(n = 100)
#   
#  invisible() 
# };  test_réelles_vs_non_identifiantes()
# 
# library(glue)
# 
# (
#   Données_non_identifiantes
#   %>% write_csv("out/filières_GHT_{year}.csv" %>% glue)
# )
# 
# 
# 
# 
# 
# 
# 
# 
