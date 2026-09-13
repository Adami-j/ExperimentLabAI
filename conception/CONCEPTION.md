## Objectif

L'application permet d'expérimenter rapidement de nouvelles technologies, méthodes et concepts liés à l'IA dans des environnements isolés.

Elle est destinée aux développeurs et chercheurs souhaitant construire, exécuter et modifier des expérimentations sans impacter directement leur environnement de travail.

Le but principal est de réduire le temps nécessaire pour passer d'une idée à une expérimentation fonctionnelle, tout en permettant de mesurer les résultats, modifier l'expérience et la réexécuter facilement.

## Périmètre V1

* Créer une expérience
* Modifier une expérience
* Lancer une expérience
* Voir le statut d'une exécution
* Consulter le résultat d'une exécution
* Consulter l'historique des exécutions d'une expérience
* Réexécuter une expérience

## Hors V1

* Authentification
* Comparaison avancée des résultats
* Monitoring GPU
* Plugins
* Dépendances entre expériences
* Orchestration de plusieurs expériences

## Cas d'utilisation

### Créer une expérience

L'utilisateur crée une expérience en définissant :

* un nom ;
* une description ;
* un timeout ;
* un script.

L'expérience est ensuite sauvegardée et peut être exécutée plusieurs fois.

### Lancer une expérience

L'utilisateur lance une expérience existante.

Une nouvelle exécution est créée et exécutée dans un environnement isolé.

L'utilisateur peut suivre son statut.

### Consulter un résultat

L'utilisateur consulte une exécution terminée.

Il peut voir :

* le résultat de l'exécution ;
* les métriques produites par le script ;
* les éventuelles erreurs ;
* les informations générales sur l'exécution.

### Consulter l'historique

L'utilisateur consulte les différentes exécutions d'une expérience afin de retrouver les résultats obtenus précédemment.

### Réexécuter une expérience

L'utilisateur peut lancer une nouvelle exécution à partir d'une expérience existante.

## Modèle métier

### Experiment

Rôle : stocke les informations principales de l'expérimentation
Informations : nom, description, script, timeout
Relations : exécution (peut avoir plusieurs exécutions en parallèle). L'historique d'une expérience correspond à l'ensemble de ses exécutions passées.

### Execution

Rôle : exécute le script de l'expérimentation
Informations : statut, temps (soit le temps en cours d'exécution, soit le temps total), résultat
Relations : résultats (peut avoir un seul résultat). Une exécution terminée fait naturellement partie de l'historique de l'expérience.

### Results

Rôle : représente la sortie du script (s'il y a une sortie)
Informations : résultats (plusieurs sorties possibles), sous différents formats : tableau Markdown, HTML, numérique, alphanumérique
Relations : les résultats sont rattachés à une exécution. Ils sont accessibles dans l'historique via l'exécution à laquelle ils appartiennent.

### Statut d'execution
Enumération : CREATED, RUNNING, SUCCESS, FAILED, TIMEOUT, CANCELLED
Description des états : 
CREATED : l’exécution a été créée mais n’a pas encore démarré.
RUNNING : le script est en cours d’exécution.
SUCCESS : l’exécution s’est terminée correctement.
FAILED : l’exécution s’est terminée avec une erreur.
TIMEOUT : l’exécution a dépassé le temps maximum autorisé.
CANCELLED : l'exécution a été annulée par l'utilisateur.

## Cycle de vie d'une exécution
```
CREATED ───────────────> CANCELLED
│
v
RUNNING ───────────────> CANCELLED
├──> SUCCESS
├──> FAILED
└──> TIMEOUT
```
## Règles métier

### Experiment : 
On peut créer une expérimentation avec un nom, sans description, sans script, sans timeout.

### Execution : 
On peut lancer une execution avec une experimentation sans script. (on retourne SUCCESS mais sans résultat)
Si il n'y a pas de timeout, on bloque à 10 minutes l'exécution et on retourne TIMEOUT.

### Statut : 
On part de CREATED->RUNNING, si on annule l'execution elle passe à CANCELLED. etc.
A partir du moment ou l'execution est en cours, elle ne repasse jamais à CREATED. Après RUNNING, l'execution ne peut que être dans l'état SUCCESS ou FAILED OU TIMEOUT OU CANCELLED.

Le TIMEOUT et CANCELLED force l'arrêt du script (et du sandbox).

### Results : 
Une exécution FAILED renvoit un resultat avec le message d'erreur complet.
Une execution Timeout renvoit un resultat générique Timeout et le message d'erreur si il y a.
Une execution Cancelled ne renvoit rien.

## Architecture

### Frontend

Responsabilité :
Permettre à l'utilisateur de créer et modifier une expérimentation, lancer ou annuler une exécution, suivre son statut et consulter ses résultats et son historique.

### Backend

Responsabilité :
Recevoir et valider les actions de l'utilisateur, appliquer les règles métier, gérer les expérimentations et les exécutions, communiquer avec le stockage et demander au Sandbox Manager de lancer ou arrêter une exécution.

### Sandbox Manager

Responsabilité :
Créer, démarrer, surveiller, arrêter et détruire les environnements isolés nécessaires aux exécutions.

### Sandbox

Responsabilité :
Fournir un environnement isolé dans lequel le script d'une expérimentation est exécuté sans impacter directement le système hôte.

### Stockage

Responsabilité :
Conserver durablement les expérimentations, les exécutions, leurs statuts, leurs résultats et les informations nécessaires à leur historique.


## Flux principal d'une exécution

1. L'utilisateur demande le lancement d'une expérience.

2. Le Backend vérifie que l'expérience existe et que les informations nécessaires à son exécution sont valides.

3. Le Backend crée une nouvelle exécution avec le statut `CREATED`.

4. Le Backend demande au Sandbox Manager de préparer un environnement isolé pour cette exécution.

5. Le Sandbox Manager crée et démarre le sandbox.

6. Lorsque le sandbox est prêt, l'exécution passe au statut `RUNNING`.

7. Le script de l'expérience est exécuté dans le sandbox.

8. Pendant l'exécution, le système surveille :

    * l'état du script ;
    * le timeout ;
    * une éventuelle demande d'annulation.

9. À la fin de l'exécution :

    * si le script se termine normalement, le statut passe à `SUCCESS` ;
    * si le script retourne une erreur, le statut passe à `FAILED` ;
    * si le timeout est atteint, le statut passe à `TIMEOUT` et le script est arrêté ;
    * si l'utilisateur annule l'exécution, le statut passe à `CANCELLED` et le script est arrêté.

10. Les résultats disponibles sont récupérés et associés à l'exécution.

11. Le Sandbox Manager arrête et détruit le sandbox.

12. Le Backend sauvegarde l'état final de l'exécution ainsi que ses résultats.

13. L'utilisateur peut consulter le statut final, les résultats et les éventuelles erreurs depuis l'interface.

## Questions ouvertes

* Quelle technologie utiliser pour implémenter les sandboxes ?
* Comment le Backend communique-t-il avec le Sandbox Manager ?
* Le Sandbox Manager fait-il partie du Backend ou doit-il être un service séparé ?
* Quels langages de script seront supportés dans la V1 ?
* Comment fournir le script et ses éventuels fichiers au sandbox ?
* Comment installer ou déclarer les dépendances nécessaires à une expérimentation ?
* Comment récupérer les sorties produites par le script ?
* Quel format utiliser pour représenter plusieurs types de résultats : texte, nombre, Markdown, HTML, fichier, tableau, etc. ?
* Comment récupérer et conserver les logs `stdout` et `stderr` ?
* Comment détecter qu'une exécution est terminée ou qu'elle a échoué ?
* Comment forcer l'arrêt d'une exécution lors d'un `TIMEOUT` ou d'une annulation ?
* Quelles limites imposer à un sandbox : CPU, RAM, GPU, disque, réseau ?
* Le réseau doit-il être accessible depuis un sandbox par défaut ?
* Comment permettre à une expérimentation d'utiliser le GPU sans compromettre l'isolation ?
* Comment gérer plusieurs exécutions simultanées ?
* Que se passe-t-il si l'application s'arrête pendant qu'une expérimentation est en cours ?
* Faut-il conserver le sandbox après une erreur pour permettre le diagnostic, ou toujours le supprimer ?
* Quels fichiers produits par une exécution doivent être conservés après la destruction du sandbox ?
* Comment réexécuter exactement une ancienne exécution avec la même configuration ?
* Quelles informations faut-il conserver pour garantir la reproductibilité d'une expérimentation ?

# Conception technique
## 1. Stack technique

### Backend
- Java
- Spring Boot
- Spring MVC
- Spring Data JPA

### Frontend
- Thymeleaf
- HTMX
- HTML/CSS

### Base de données
- PostgreSQL

### Sandboxing
- Docker

### Tests
- JUnit
- Testcontainers

### Build
- Maven

## 2. Architecture technique

L'application est construite sous la forme d'un monolithe Spring Boot.

Le Sandbox Manager est un module interne du Backend. Il est responsable de la gestion du cycle de vie des sandboxes et communique avec Docker pour créer, démarrer, surveiller, arrêter et supprimer les conteneurs utilisés par les exécutions.

### Composants

#### Web

Responsable de l'interface utilisateur avec Thymeleaf et HTMX ainsi que de la réception des actions utilisateur.

#### Experiment

Responsable de la gestion des expérimentations : création, modification et consultation.

#### Execution

Responsable de la création des exécutions, de leur cycle de vie et de leur statut.

#### Sandbox Manager

Responsable de la préparation et du contrôle des environnements d'exécution isolés.

Il utilise Docker pour :

* créer un sandbox ;
* démarrer un sandbox ;
* arrêter un sandbox ;
* supprimer un sandbox ;
* récupérer son état.

#### Result

Responsable de la récupération et de la conservation des résultats produits par une exécution.

#### Persistence

Responsable de la persistance des expérimentations, exécutions et résultats dans PostgreSQL.

### Vue générale
```
Frontend Thymeleaf / HTMX
|
v
Spring Boot
|
+-- Experiment
|
+-- Execution
|      |
|      v
|  Sandbox Manager
|      |
|      v
|    Docker
|
+-- Result
|
+-- Persistence
|
v
PostgreSQL
```

## 3. Modèle de données

## 3. Modèle de données

### Table `experiment`

Représente une expérimentation enregistrée dans l'application.

Champs :

* `id` : identifiant unique
* `name` : nom de l'expérimentation
* `description` : description optionnelle
* `script` : contenu du script à exécuter
* `timeout_seconds` : timeout défini pour l'expérimentation
* `created_at` : date de création
* `updated_at` : date de dernière modification

Contraintes :

* `name` obligatoire
* `description` optionnelle
* `script` optionnel
* si `timeout_seconds` est absent, la valeur par défaut appliquée lors de l'exécution est de 600 secondes

---

### Table `experiment_dependency`

Représente une dépendance Python nécessaire à l'exécution d'une expérimentation.

Champs :

* `id` : identifiant unique
* `experiment_id` : expérimentation associée
* `package_name` : nom du package Python
* `version_constraint` : contrainte de version optionnelle
* `created_at` : date de création

Exemples :

```text
torch
transformers==5.2.0
numpy>=2.0
accelerate~=1.3
```

Relations :

* une `Experiment` peut avoir zéro à plusieurs `ExperimentDependency`
* une `ExperimentDependency` appartient à une seule `Experiment`

Contraintes :

* `package_name` obligatoire
* `version_constraint` optionnelle
* deux dépendances identiques ne doivent pas être déclarées plusieurs fois pour la même expérimentation

---

### Table `execution`

Représente une tentative d'exécution d'une expérimentation.

Champs :

* `id` : identifiant unique
* `experiment_id` : expérimentation associée
* `status` : statut de l'exécution
* `created_at` : date de création
* `started_at` : date de démarrage
* `finished_at` : date de fin
* `timeout_seconds` : timeout réellement utilisé pour cette exécution
* `error_message` : message d'erreur éventuel

Valeurs possibles pour `status` :

* `CREATED`
* `RUNNING`
* `SUCCESS`
* `FAILED`
* `TIMEOUT`
* `CANCELLED`

Relations :

* une `Experiment` possède plusieurs `Execution`
* une `Execution` appartient à une seule `Experiment`

Le timeout est copié dans l'exécution au moment de son lancement afin de conserver la configuration réellement utilisée.

---

### Table `result`

Représente une sortie produite par une exécution.

Champs :

* `id` : identifiant unique
* `execution_id` : exécution associée
* `name` : nom ou identifiant du résultat
* `type` : type du résultat
* `content` : contenu du résultat
* `created_at` : date de création

Types de résultat possibles dans la V1 :

* `TEXT`
* `NUMBER`
* `MARKDOWN`
* `HTML`

Relations :

* une `Execution` peut produire zéro à plusieurs `Result`
* un `Result` appartient à une seule `Execution`

---

### Relations

```text
Experiment
    1
    |
    | N
    +------> ExperimentDependency

    1
    |
    | N
    v
Execution
    1
    |
    | N
    v
Result
```


### Relations

```text
Experiment
    1
    |
    | N
    v
Execution
    1
    |
    | N
    v
Result
```

### Historique

Aucune table `history` n'est nécessaire.

L'historique d'une expérimentation correspond simplement à l'ensemble de ses exécutions, ordonnées par date.

### Durée d'une exécution

La durée n'est pas stockée directement.

Elle est calculée à partir de :

```text
RUNNING
date actuelle - started_at

TERMINÉE
finished_at - started_at
```

## 4. API et échanges entre composants

### Interface utilisateur

L'interface utilisateur est générée côté serveur avec Thymeleaf.

HTMX est utilisé lorsque des interactions dynamiques sont nécessaires, notamment pour :

* lancer une exécution ;
* annuler une exécution ;
* actualiser son statut ;
* afficher les résultats sans recharger entièrement la page.

Le Frontend communique uniquement avec le Backend Spring Boot.

### Routes principales

#### Expérimentations

* `GET /experiments` : afficher les expérimentations
* `GET /experiments/new` : afficher le formulaire de création
* `POST /experiments` : créer une expérimentation
* `GET /experiments/{id}` : afficher une expérimentation
* `GET /experiments/{id}/edit` : afficher le formulaire de modification
* `POST /experiments/{id}` : modifier une expérimentation

#### Exécutions

* `POST /experiments/{id}/executions` : lancer une nouvelle exécution
* `GET /executions/{id}` : consulter une exécution
* `POST /executions/{id}/cancel` : annuler une exécution
* `GET /executions/{id}/status` : récupérer le statut d'une exécution
* `GET /experiments/{id}/executions` : consulter l'historique des exécutions

Les routes exactes pourront évoluer pendant l'implémentation.

### Échanges Backend / Sandbox Manager

Le Sandbox Manager étant un module interne de l'application, la communication se fait directement par appels Java.

Le module `Execution` demande au Sandbox Manager :

* de préparer un sandbox ;
* d'exécuter un script ;
* de récupérer son état ;
* de l'arrêter ;
* de le supprimer.

Le reste de l'application ne communique pas directement avec Docker.

---

## 5. Gestion des exécutions

Les exécutions sont traitées de manière asynchrone afin qu'une requête HTTP ne reste pas ouverte pendant toute la durée d'une expérimentation.

### Lancement

Lorsqu'un utilisateur lance une expérimentation :

1. Le Backend valide la demande.
2. Une `Execution` est créée avec le statut `CREATED`.
3. La requête utilisateur se termine sans attendre la fin de l'exécution.
4. L'exécution est transmise au mécanisme d'exécution asynchrone.
5. Le Sandbox Manager prépare le sandbox.
6. Lorsque le sandbox est prêt, l'exécution passe à `RUNNING`.
7. Le script est exécuté.
8. Le résultat final détermine le statut de l'exécution.

### États finaux

Une exécution peut terminer avec :

* `SUCCESS`
* `FAILED`
* `TIMEOUT`
* `CANCELLED`

Un état final ne peut plus revenir à `RUNNING` ou `CREATED`.

### Exécutions simultanées

Plusieurs exécutions peuvent fonctionner simultanément.

La V1 utilisera un nombre limité d'exécutions concurrentes afin d'éviter d'épuiser les ressources de la machine.

La valeur exacte de cette limite sera configurable.

### Annulation

Lorsqu'une annulation est demandée :

1. le système vérifie que l'exécution peut encore être annulée ;
2. le Sandbox Manager arrête le sandbox ;
3. l'exécution passe à `CANCELLED` ;
4. le sandbox est supprimé.

### Timeout

Le timeout utilisé est celui enregistré dans l'`Execution`.

Si aucun timeout n'a été défini dans l'expérimentation, une valeur de 600 secondes est utilisée.

Lorsque le timeout est atteint :

1. le script est interrompu ;
2. le sandbox est arrêté ;
3. l'exécution passe à `TIMEOUT` ;
4. les informations disponibles sont récupérées ;
5. le sandbox est supprimé.

---

## 6. Gestion des sandboxes

### Principe

Chaque exécution dispose de son propre environnement isolé.

Dans la V1, les sandboxes sont implémentés avec Docker.

```text
Execution
    |
    v
Sandbox Manager
    |
    v
Docker
    |
    v
Container
    |
    v
Script
```

### Cycle de vie

Pour chaque exécution, le Sandbox Manager :

1. prépare la configuration du sandbox ;
2. crée le conteneur ;
3. fournit le script au conteneur ;
4. démarre le conteneur ;
5. surveille son exécution ;
6. récupère les sorties nécessaires ;
7. arrête le conteneur si nécessaire ;
8. supprime le conteneur.

### Identification

Chaque sandbox doit être associé de manière unique à une `Execution`.

L'identifiant de l'exécution pourra être utilisé dans les métadonnées ou labels Docker afin de retrouver le conteneur correspondant.

### Images Docker

La V1 commence avec un nombre limité d'environnements supportés.

Le premier environnement peut être basé sur Python afin de permettre l'exécution de scripts liés à l'IA.

Les images disponibles sont contrôlées par l'application.

L'utilisateur ne fournit pas directement une image Docker arbitraire dans la V1.

### Ressources

Les sandboxes doivent pouvoir être limités en :

* mémoire ;
* CPU ;
* durée d'exécution.

La gestion avancée du GPU n'est pas nécessaire pour la première version.

### Nettoyage

Un sandbox doit normalement être supprimé après chaque exécution, quel que soit son résultat.

Le Sandbox Manager doit également pouvoir détecter et supprimer les sandboxes laissés dans un état incohérent après un problème applicatif.

---

## 7. Gestion des résultats et logs

### Résultats

Une exécution peut produire zéro à plusieurs résultats.

Les résultats sont explicitement produits par le script selon un format défini par l'application.

Types supportés dans la V1 :

* `TEXT`
* `NUMBER`
* `MARKDOWN`
* `HTML`

Chaque résultat possède :

* un nom ;
* un type ;
* un contenu.

### Format d'échange

Un format standard devra être défini entre le script et l'application.

Exemple conceptuel :

```json
{
  "results": [
    {
      "name": "accuracy",
      "type": "NUMBER",
      "content": "0.94"
    },
    {
      "name": "report",
      "type": "MARKDOWN",
      "content": "## Résultat\n..."
    }
  ]
}
```

Le format exact sera défini pendant l'implémentation du protocole d'exécution.

### Logs

Les logs techniques sont séparés des résultats.

Deux flux sont distingués :

* `stdout`
* `stderr`

Les logs permettent de comprendre le déroulement d'une expérimentation et de diagnostiquer une erreur.

Ils ne sont pas considérés comme des `Result`.

Pour la V1, les logs peuvent être récupérés à la fin de l'exécution et conservés avec l'exécution.

Une gestion temps réel des logs pourra être ajoutée ultérieurement.

### Erreurs

Lorsqu'une exécution échoue, le message d'erreur et les logs disponibles sont conservés.

Une exécution `FAILED` peut donc ne produire aucun résultat fonctionnel tout en conservant les informations nécessaires au diagnostic.

---

## 8. Gestion des erreurs et reprise

### Erreur du script

Si le script termine avec une erreur :

* l'exécution passe à `FAILED` ;
* le code de sortie est conservé si disponible ;
* `stdout` et `stderr` sont récupérés ;
* le message d'erreur est conservé ;
* le sandbox est supprimé.

### Erreur de création du sandbox

Si le sandbox ne peut pas être créé ou démarré :

* l'exécution passe à `FAILED` ;
* l'erreur technique est conservée ;
* aucune tentative automatique de relance n'est effectuée dans la V1.

### Erreur de l'application

Une exécution ne doit pas rester indéfiniment dans l'état `RUNNING` si l'application est interrompue.

Au démarrage de l'application, un mécanisme de récupération vérifie les exécutions `CREATED` et `RUNNING`.

Le système compare leur état avec les sandboxes réellement présents.

Une exécution dont le sandbox n'existe plus est considérée comme interrompue et passe à `FAILED`.

### Retry

La V1 ne relance pas automatiquement une exécution échouée.

L'utilisateur peut manuellement réexécuter l'expérimentation, ce qui crée une nouvelle `Execution`.

L'ancienne exécution reste conservée dans l'historique.

---

## 9. Sécurité et isolation

### Principe

Les scripts exécutés doivent être considérés comme potentiellement dangereux.

Ils ne doivent pas être exécutés directement par le processus Spring Boot ni directement sur le système hôte.

### Isolation

Chaque script est exécuté dans un conteneur Docker dédié.

Le conteneur doit utiliser le minimum de permissions nécessaires.

### Accès au système hôte

Par défaut, un sandbox ne doit pas :

* accéder au système de fichiers de l'hôte ;
* accéder au socket Docker ;
* lancer des conteneurs supplémentaires ;
* disposer de privilèges élevés.

Les volumes montés dans le sandbox doivent être explicitement contrôlés par le Sandbox Manager.

### Réseau

La politique réseau doit être restrictive.

Pour la V1, l'accès réseau doit être configurable selon les besoins de l'expérimentation.

Une expérimentation ne nécessitant pas Internet devrait pouvoir être exécutée sans accès réseau.

### Ressources

Les limites de CPU, mémoire et timeout empêchent une expérimentation de monopoliser indéfiniment les ressources de la machine.

### HTML produit par les scripts

Les résultats HTML doivent être considérés comme non fiables.

Ils ne doivent pas être injectés directement dans l'interface sans mécanisme de protection adapté afin d'éviter l'exécution de contenu malveillant dans le navigateur.

### Secrets

Aucun secret de l'application, identifiant de base de données ou information sensible ne doit être automatiquement transmis aux sandboxes.

---

## 10. Tests techniques

### Tests unitaires

Les règles métier principales doivent être testées indépendamment de Docker et PostgreSQL.

Exemples :

* transitions de statut autorisées ;
* calcul du timeout ;
* validation d'une expérimentation ;
* comportement lors d'une annulation.

### Tests d'intégration PostgreSQL

Testcontainers est utilisé pour lancer une véritable instance PostgreSQL pendant les tests.

Les tests vérifient notamment :

* la persistance des expérimentations ;
* la persistance des exécutions ;
* les relations entre les entités ;
* la persistance des résultats ;
* la récupération de l'historique.

### Tests d'intégration Docker

Une série de tests vérifie le Sandbox Manager avec de véritables conteneurs.

Scénarios minimum :

* exécution réussie ;
* script sans résultat ;
* script en erreur ;
* script dépassant le timeout ;
* annulation d'une exécution ;
* récupération des logs ;
* destruction correcte du sandbox.

### Tests du flux complet

Un test de bout en bout doit couvrir le scénario principal :

```text
Création Experiment
        |
        v
Lancement Execution
        |
        v
Création Sandbox
        |
        v
Exécution Script
        |
        v
Récupération Result
        |
        v
SUCCESS
        |
        v
Consultation Result
```

### Tests de nettoyage

Des tests spécifiques doivent vérifier qu'aucun sandbox ne reste actif après :

* `SUCCESS`
* `FAILED`
* `TIMEOUT`
* `CANCELLED`

### Tests des cas limites

Les cas suivants doivent également être couverts :

* expérimentation sans script ;
* expérimentation sans timeout ;
* script retournant plusieurs résultats ;
* résultat invalide ;
* erreur Docker ;
* plusieurs exécutions simultanées.
