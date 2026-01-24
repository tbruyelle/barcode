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
└── items/
    └── grocery_item.tscn  # Article scannable (RigidBody3D)

scripts/
├── game_manager.gd        # Logique du jeu (spawn, grab, scan, vitesse tapis, clients)
├── player.gd              # Caméra première personne (rotation souris)
├── grocery_item.gd        # Comportement des articles + détection tapis + effet scanné
├── customer.gd            # Comportement du client (déplacement le long de la caisse)
└── beep_generator.gd      # Génération procédurale du son de bip
```

## Gameplay

- **Position joueur/caissier** : z=-1.6 (au niveau de la caméra), face au comptoir
- **Tapis roulant** : x=-1.5, articles avancent de gauche à droite (x+)
- **Scanner** : Sur le comptoir, zone de détection verte, laser rouge
- **Bac de réception** : Creusé dans le comptoir avec pente descendante vers le panier
- **Panier de course** : Reçoit les articles scannés en bas de la pente
- **Rayons supermarché** : 3 allées de 12m avec étagères double-face et produits variés

## Disposition spatiale de la caisse

```
        x- (gauche)                              x+ (droite)
            ←────────────────────────────────────────→

                    TAPIS           SCANNER      PANIER
     z+            ┌───────────────┬───────┬──────────┐
   (clients)       │   x=-1.5      │  x=0  │  x=1.17  │  ← Comptoir (z=-0.8)
                   └───────────────┴───────┴──────────┘
     z-              JOUEUR/CAISSIER (z=-1.6, caméra)
```

- **Début de la caisse** : x négatif (côté tapis, x ≈ -1.5) - où les articles arrivent
- **Fin de la caisse** : x positif (côté panier, x ≈ 1.17) - où les articles scannés sortent
- **Côté clients** : z positif (z ≈ 0.2), de l'autre côté du comptoir
- **Côté caissier** : z négatif (z = -1.6), où se trouve la caméra/joueur

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
- Produits étagères : 8 couleurs (rouge, jaune, vert, bleu, orange, violet, rose, marron), ~330 produits avec codes-barres

## À faire (idées futures)

- Interface de score
- File de clients (un client implémenté, à étendre pour une file d'attente)
- Système de difficulté progressive
