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
├── game_manager.gd        # Logique du jeu (grab, scan, clients, HUD)
├── player.gd              # Caméra première personne (rotation souris)
├── grocery_item.gd        # Comportement des articles + détection tapis + effet scanné
├── customer.gd            # Client avec state machine (dépôt, marche, collecte, départ)
├── cash_register.gd       # Caisse enregistreuse (tiroir animé)
├── beep_generator.gd      # Génération procédurale du son de bip
├── detection_zone.gd      # Animation scintillante de la zone de détection
├── laser_glow.gd          # Lueur rouge animée le long des lasers
└── neon_light.gd          # Effet néon (scintillement + grésillement)
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
- **Bouton jaune** : Ouvrir/fermer le tiroir-caisse

## Points techniques importants

1. **Collision des objets tenus** : `gravity_scale = 0`, `collision_layer = 2` quand tenu. Déplacement par `linear_velocity` (pas position directe) pour que la physique gère les collisions. L'objet tourne naturellement en cas de collision (`angular_damp = 3.0`). Détection du scan en continu dans `_physics_process`.

2. **Détection tapis roulant** : Vérification position (X, Y, Z) dans `grocery_item.gd` - les objets ne bougent que s'ils sont sur le tapis (Y >= 0.8)

3. **Scan d'article** :
   - Distance à la zone scanner <= 0.25
   - Code-barre doit faire face au scanner (dot product > 0.3)
   - Son de bip généré programmatiquement (1000Hz, 0.15s)
   - Halo vert pulsant sur les articles scannés

4. **CSGBox3D** : `use_collision = true` nécessaire pour les collisions physiques

5. **Vitesse du tapis** : Constante `CONVEYOR_SPEED = 0.6` dans `game_manager.gd`, accessible via `get_parent().CONVEYOR_SPEED` depuis `grocery_item.gd`.

6. **Spawn des articles** : Piloté par le client. `generate_item_data()` crée les données (couleur, nom, taille, prix). `instantiate_item(data)` instancie le RigidBody3D sur le tapis. Méthode `set_appearance()` dans `grocery_item.gd`.

7. **Projection des objets** : Les objets sont projetés dans la direction de la caméra au lâcher (`THROW_FORCE = 3.0`)

8. **Client** : Sprite3D avec billboard axe Y + state machine (DEPOSITING → WALKING_TO_BASKET → COLLECTING → LEAVING) :
   - **DEPOSITING** : Apparaît à (-2.1, 0, 0.2) avec articles en orbite. Dépose un article toutes les 2s sur le tapis via tween + `instantiate_item()`
   - **WALKING_TO_BASKET** : Marche vers (1.5, 0, 0.2) avec animation bob/sway (0.8/0.6 Hz)
   - **COLLECTING** : Pause 2s au panier. Les articles scannés deviennent des visuels orbitants, les physiques sont `queue_free()`
   - **LEAVING** : Marche vers la porte (5, 0, 0.2) avec articles collectés en orbite. Signal `customer_left` → `queue_free()` + nouveau client après 2s
   - **Orbite** : rayon 0.4m, vitesse 1.5 rad/s, hauteur variable (0.6 + 0.3*sin)
   - **HUD** : Réinitialisé à chaque nouveau client (`_reset_hud()`)

9. **Rebords** : Petits rebords sur le tapis roulant (avant/arrière) et le comptoir (côté client) pour empêcher les objets de tomber

10. **Caisse enregistreuse** : Scène séparée (`cash_register.tscn`) avec script `cash_register.gd`. Tiroir animé via Tween (ouverture avec TRANS_BACK pour effet rebond). Bouton jaune dans le groupe `drawer_button`, détecté par raycast dans `game_manager.gd`

11. **HUD articles scannés** : Panneau semi-transparent en haut à droite (PanelContainer sous UI/CanvasLayer). Police monospace console. Affiche la liste des articles scannés avec prix et le total en bas. Mis à jour en temps réel dans `scan_item()` via `game_manager.gd`. Auto-scroll vers le dernier article via `ensure_control_visible`.

12. **Sons de collision** : Chaque article a un `AudioStreamPlayer3D` (`CollisionSound`). Son procédural (80ms, 80-240Hz, décroissance exp). Volume proportionnel à la vitesse d'impact (seuil 0.3 m/s), pitch aléatoire (0.8-1.3x). Nécessite `contact_monitor = true` et `max_contacts_reported = 4` sur le RigidBody3D.

13. **Effets visuels scanner** : `detection_zone.gd` anime l'alpha et l'émission de la DetectionZone (3 ondes superposées 6/14/23 Hz). `laser_glow.gd` fait voyager une sphère lumineuse rouge le long de chaque LaserBeam (droite→gauche horizontal, haut→bas vertical), intensité variable selon la position.

14. **Néons** : `neon_light.gd` sur les 3 CeilingLight. Scintillement aléatoire (0.5%/frame, 50-250ms) avec variation d'intensité 30-110%. Grésillement procédural 50Hz + harmoniques en AudioStreamPlayer3D spatial. Micro-variations indépendantes par lumière.

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

- File de clients (file d'attente visible avec plusieurs clients)
- Système de difficulté progressive
