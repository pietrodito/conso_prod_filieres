# --- Configuration ---
dossier_r <- "R"
annee_debut <- 2024
annee_fin <- 2025

# Récupérer et trier les scripts R par ordre alphabétique strict
noms_fichiers <- list.files(path = dossier_r, pattern = "\\.[rR]$", full.names = FALSE)
fichiers_r <- list.files(path = dossier_r, pattern = "\\.[rR]$", full.names = TRUE)

if (length(noms_fichiers) > 0) {
  ordre <- order(noms_fichiers)
  noms_fichiers <- noms_fichiers[ordre]
  fichiers_r <- fichiers_r[ordre]
}

# Vérification de l'existence des scripts
if (length(fichiers_r) == 0) {
  cat("Aucun script R trouvé dans le dossier '", dossier_r, "'.\n", sep = "")
} else {
  cat("==================================================\n")
  cat(sprintf(" Lancement des scripts pour la période : %d - %d\n", annee_debut, annee_fin))
  cat(sprintf(" Nombre de scripts par année : %d\n", length(fichiers_r)))
  cat("==================================================\n\n")
  
  # Boucle principale sur les années
  for (annee in seq(annee_debut, annee_fin)) {
    cat(sprintf("==================================================\n"))
    cat(sprintf(" ANNÉE EN COURS : %d\n", annee))
    cat(sprintf("==================================================\n"))
    
    # Définir ou mettre à jour la variable globale 'year'
    assign("year", annee, envir = .GlobalEnv)
    
    # Boucle d'exécution sur chaque fichier
    for (i in seq_along(fichiers_r)) {
      chemin_actuel <- fichiers_r[i]
      nom_actuel <- noms_fichiers[i]
      
      cat(sprintf("[%d/%d] Exécution de %s (year = %d)... ", i, length(fichiers_r), nom_actuel, annee))
      
      # Mesurer le temps d'exécution
      temps_exec <- system.time({
        tryCatch({
          source(chemin_actuel, local = FALSE, encoding = "UTF-8")
        }, error = function(e) {
          cat(sprintf("\n -> ERREUR dans %s (Année %d) : %s\n", nom_actuel, annee, e$message))
        })
      })
      
      cat(sprintf("Fait en %.2fs\n", temps_exec["elapsed"]))
    }
    cat("\n")
  }
  
  cat("==================================================\n")
  cat(" Traitement global terminé avec succès !\n")
  cat("==================================================\n")
}