# Barcode - Simulateur de caissier/caissière

Jeu 3D Godot 4.5 où le joueur incarne un caissier de supermarché. Il ne peut pas bouger mais peut tourner la tête. Les articles arrivent sur un tapis roulant et doivent être scannés en orientant le code-barre vers le lecteur.

## Workflow

- Update CLAUDE.md before each time you're asked to commit.

## Structure du projet

```
scenes/
├── main.tscn              # Scène principale (caisse, tapis, scanner, UI, environnement)
├── shelves.tscn           # Rayons du supermarché avec produits (~660 objets)
├── customer.tscn          # Client (Sprite3D billboard)
├── cash_register.tscn     # Caisse enregistreuse avec boutons et tiroir
└── items/
    └── grocery_item.tscn  # Article scannable (RigidBody3D)

scripts/
├── game_manager.gd        # Logique du jeu (spawn, grab, scan, vitesse tapis, clients)
├── player.gd              # Caméra première personne (rotation souris)
├── grocery_item.gd        # Comportement des articles + détection tapis + effet scanné
├── customer.gd            # Comportement du client (déplacement le long de la caisse)
├── cash_register.gd       # Caisse enregistreuse (tiroir animé)
├── beep_generator.gd      # Génération procédurale du son de bip
├── detection_zone.gd      # Animation scintillante de la zone de détection
└── laser_glow.gd          # Lueur rouge animée le long des lasers
```

## Gameplay

- **Position joueur/caissier** : z=-1.6, caméra regarde vers z+ (vers les clients)
- **Tapis roulant** : x=-1.5, z=-0.8, à DROITE du caissier, articles avancent de droite à gauche (x+)
- **Scanner** : x=0, z=-0.8, au CENTRE du comptoir, zone de détection verte, laser rouge
- **Bac de réception** : Creusé dans le comptoir avec pente descendante vers le panier
- **Panier de course** : x=1.17, z=-0.8, à GAUCHE du caissier, reçoit les articles scannés
- **Rayons supermarché** : 3 allées de 12m avec étagères double-face et produits variés
- **Caisse enregistreuse** : x=-0.93, z=-1.38, à DROITE et légèrement DERRIÈRE le caissier. Boutons décoratifs + bouton jaune pour ouvrir/fermer le tiroir

## Disposition spatiale de la caisse

```
        x+ (gauche caissier)                     x- (droite caissier)
            ────────────────────────────────────────→

                    PANIER          SCANNER      TAPIS
     z+            ┌───────────────┬───────┬──────────┐
   (devant)        │   x=1.17      │  x=0  │  x=-1.5  │  ← Comptoir (z=-0.8)
   clients         └───────────────┴───────┴──────────┘

     z-              CAISSIER (z=-1.6) regarde vers z+
  (derrière)          CAISSE ENREG. (x=-0.93, z=-1.38)
```

**Orientation** (caissier à z=-1.6, regarde vers z+) :
- **Gauche** (x+) : Panier (x=1.17)
- **Centre** (x=0) : Scanner
- **Droite** (x-) : Tapis roulant (x=-1.5), Caisse enregistreuse (x=-0.93)
- **Devant** (z+) : Comptoir puis clients (z=0.2, se déplacent de x=-3 à x=1.5)
- **Derrière** (z-) : Côté caissier

## Contrôles

- **Souris** : Regarder autour
- **Clic gauche** : Prendre/lâcher un objet (les objets sont projetés vers l'avant au lâcher)
- **Q/E/R** : Tourner l'objet (axes X/Y/Z)
- **Molette** : Tourner l'objet (axe X)
- **Échap** : Libérer/capturer la souris
- **Boutons sur comptoir** : Contrôler la vitesse du tapis
  - Vert : Diminuer la vitesse
  - Rouge : Augmenter la vitesse
  - Violet : Vitesse maximale (death mode)

## Points techniques importants

1. **Collision des objets tenus** : `collision_layer = 0` quand tenu, donc la détection du scan se fait en continu dans `_physics_process` (pas via Area3D signal)

2. **Détection tapis roulant** : Vérification position (X, Y, Z) dans `grocery_item.gd` - les objets ne bougent que s'ils sont sur le tapis (Y >= 0.8)

3. **Scan d'article** :
   - Distance à la zone scanner <= 0.25
   - Code-barre doit faire face au scanner (dot product > 0.3)
   - Son de bip généré programmatiquement (1000Hz, 0.15s)
   - Halo vert pulsant sur les articles scannés

4. **CSGBox3D** : `use_collision = true` nécessaire pour les collisions physiques

5. **Vitesse du tapis** : Configurable via boutons (min: 0.3, max: 2.0), stockée dans `game_manager.gd` et accessible via `get_parent().conveyor_speed`. Affecte aussi la fréquence de spawn des articles.

6. **Spawn des articles** : Position fixe avec rotation aléatoire. Articles générés avec couleurs et tailles variées (8 couleurs, tailles aléatoires). Prix calculé selon le volume. Méthode `set_appearance()` dans `grocery_item.gd`.

7. **Projection des objets** : Les objets sont projetés dans la direction de la caméra au lâcher (`THROW_FORCE = 3.0`)

8. **Client** : Sprite3D avec billboard axe Y. Animation de marche naturelle :
   - Rebond vertical (bob) : fréquence 0.8 Hz, amplitude 0.01m
   - Balancement latéral (sway) : fréquence 0.6 Hz, amplitude 0.02 rad
   - Déplacement : 0.1 m/s du début (x=-3) vers la fin (x=1.5) de la caisse

9. **Rebords** : Petits rebords sur le tapis roulant (avant/arrière) et le comptoir (côté client) pour empêcher les objets de tomber

10. **Caisse enregistreuse** : Scène séparée (`cash_register.tscn`) avec script `cash_register.gd`. Tiroir animé via Tween (ouverture avec TRANS_BACK pour effet rebond). Bouton jaune dans le groupe `drawer_button`, détecté par raycast dans `game_manager.gd`

11. **HUD articles scannés** : Panneau semi-transparent en haut à droite (PanelContainer sous UI/CanvasLayer). Police monospace console. Affiche la liste des articles scannés avec prix et le total en bas. Mis à jour en temps réel dans `scan_item()` via `game_manager.gd`. Auto-scroll vers le dernier article via `ensure_control_visible`.

12. **Sons de collision** : Chaque article a un `AudioStreamPlayer3D` (`CollisionSound`). Son procédural (80ms, 80-240Hz, décroissance exp). Volume proportionnel à la vitesse d'impact (seuil 0.3 m/s), pitch aléatoire (0.8-1.3x). Nécessite `contact_monitor = true` et `max_contacts_reported = 4` sur le RigidBody3D.

13. **Effets visuels scanner** : `detection_zone.gd` anime l'alpha et l'émission de la DetectionZone (3 ondes superposées 6/14/23 Hz). `laser_glow.gd` fait voyager une sphère lumineuse rouge le long de chaque LaserBeam (droite→gauche horizontal, haut→bas vertical), intensité variable selon la position.

## Environnement

- **Pièce fermée** : 4 murs (20x25m), plafond à 3m
- **Éclairage** : 2 OmniLight3D au plafond
- **Porte coulissante** : Mur Est, 2 panneaux vitrés
- **Comptoir** : Avec bac creusé (CSGCombiner3D + soustraction) et pente
- **Rayons** : 3 allées (Rayon1/2/3) à x=-9, espacées de 5m en z. Panneau central bleu foncé (12m x 2m x 0.15m), étagères des deux côtés à 3 hauteurs (0.4, 0.9, 1.4m)

## Éléments visuels

- Viseur "+" blanc au centre de l'écran
- Zone de détection : cube vert semi-transparent
- Laser : ligne rouge sur le scanner
- Code-barre : partie blanche sur les articles
- Halo pulsant : vert semi-transparent sur articles scannés
- Panier de course : bleu, en bas de la pente
- Caisse enregistreuse : corps gris foncé, écran vert foncé incliné, boutons crème (6 décoratifs), bouton vert (total), bouton jaune (tiroir), tiroir gris clair animé
- Produits étagères : 8 couleurs (rouge, jaune, vert, bleu, orange, violet, rose, marron), ~330 produits avec codes-barres
- HUD scan : panneau sombre semi-transparent en haut à droite, police monospace, titre "Articles scannés", liste scrollable, séparateur, total jaune

## À faire (idées futures)

- File de clients (un client implémenté, à étendre pour une file d'attente)
- Système de difficulté progressive
