; Afficher un bloc de pixels en assembleur sur Atari ST
; On peut le déplacer avec les flèches du clavier, au pixel près.
; Par Vretrocomputing, 2026.

	bsr	savemode	;Sauvegarder le mode vidéo

	clr.w	-(sp)		;Basse résolution
	move.l	#-1,-(sp)	;Ne pas changer l'adresse physique
	move.l	#-1,-(sp)	;Ne pas changer l'adresse logique
	move.w	#5,-(sp)	;Setscreen
	trap	#14		;XBIOS
	add.l	#12,sp

	DC.W	$a00a		;Line A 10 : Cacher la souris

	move.l	#pi1+2,-(sp)	;Nouvelle palette
	move.w	#6,-(sp)	;Setpalette
	trap	#14		;XBIOS
	addq.l	#6,sp

	move.w	#3,-(sp)	;Logbase
	trap	#14		;XBIOS
	addq.l	#2,sp

	move.l	d0,a3			;Adresse de l'écran (framebuffer)
	lea	(98*160)+(64/2)(a3),a4	;Adresse du bloc de destination
	moveq	#0,d4			;Offset x en pixels, entre 0 et 15

redraw:

; Copier l'image source
	move.l	#pi1+34,a0	;Source : image
	move.l	a3,a1		;Destination : écran

	move.w	#32000/4-1,d0	;Nombre de longs - 1
copie:
	move.l	(a0)+,(a1)+	;Copier un long
	dbra	d0,copie

; Copier le panneau Xenon par dessus

	move.l	#pi1+34+(56*160)+(240/2),a0	;Source
	move.l	a4,a1				;Destination

	move.w	#48-1,d1	;Hauteur en pixels
copie_y:
	;Copier une ligne
	;a1 = adresse de destination
	;d4 = offset x en pixels, de 0 à 15

	; Groupe de gauche
	REPT	4		;4 plans
	move.w	(a0)+,d0	;Lire le mot source courant
	lsr.w	d4,d0		;Décaler les pixels à droite

	move.w	#$ffff,d2	;Masque
	lsr.w	d4,d2		;Décaler le masque à droite
	not.w	d2		;NOT Masque
	and.w	d2,(a1)		;Fond = Fond AND (NOT Masque)

	or.w	d0,(a1)+	;Fond = Fond OR Source
	ENDR

	; Groupes du milieu
	REPT	4*3		;4 plans x 3 groupes de large
	move.w	-8(a0),d0	;Lire le mot source précédent
	swap	d0		;Le faire passer dans le mot de poids fort
	move.w	(a0)+,d0	;Lire le mot source courant
	lsr.l	d4,d0		;Décaler les pixels à droite
	move.w	d0,(a1)+	;Ecrire le mot de destination
	ENDR

	; Groupe de droite
	lea	-8(a0),a0	;Revenir sur le groupe source précédent
	REPT	4		;4 plans
	move.w	(a0)+,d0	;Lire le mot source courant
	swap	d0		;Faire passer le mot source dans le mot fort
	clr.w	d0		;Mettre le mot faible à 0
	lsr.l	d4,d0		;Décaler les pixels à droite

	move.l	#$ffff0000,d2	;Masque
	lsr.l	d4,d2		;Décaler le masque à droite
	not.w	d2		;NOT Masque
	and.w	d2,(a1)		;Fond = Fond AND (NOT Masque)

	or.w	d0,(a1)+	;Fond = Fond OR Source
	ENDR

	;Ligne suivante
	add.l	#(320-64)/2,a0		;Ligne source suivante
	add.l	#(320-64-16)/2,a1	;Ligne destination suivante
	dbra	d1,copie_y

; Attendre l'appui sur une touche

wait:
	move.w	#8,-(sp)	;Cnecin
	trap	#1		;GEMDOS
	addq.l	#2,sp

	;Ici : d0.b = code ASCII

	cmp.b	#$1b,d0		;Escape ?
	beq	exit

	swap	d0		;Inverser scancode et code ASCII

	cmp.b	#$50,d0		;Flèche Bas ?
	beq	down

	cmp.b	#$48,d0		;Flèche Haut ?
	beq	up

	cmp.b	#$4b,d0		;Flèche Gauche ?
	beq	left

	cmp.b	#$4d,d0		;Flèche Droite ?
	beq	right

	bra	wait

down:
	add.l	#160,a4		;Une ligne plus bas
	bra	redraw

up:
	sub.l	#160,a4		;Une ligne plus haut
	bra	redraw

right:
	addq.w	#1,d4		;Un pixel de plus à droite
	cmp.w	#16,d4		;On a atteint le pixel 16 ?
	blo	redraw		;Pas encore
	moveq	#0,d4		;Pixel 16 : on revient à 0
	addq.l	#8,a4		;et on passe au groupe de 16 pixels suivant
	bra	redraw

left:
	subq.w	#1,d4		;Un pixel de plus à gauche
	bcc	redraw		;Si pas débordé sous de 0 : rien de plus
	moveq	#15,d4		;Sinon on recommence au pixel 15
	subq.l	#8,a4		;et on va au groupe de 16 pixels précédent
	bra	redraw

exit:
	bsr	restoremode	;Restaurer le mode vidéo

	clr.w	-(sp)		;Pterm0
	trap	#1		;GEMDOS

;--------------------------------------------------------------------------
; Sauvegarder le mode vidéo
;--------------------------------------------------------------------------
savemode:
	move.w	#4,-(sp)	;Getrez
	trap	#14		;XBIOS
	addq.l	#2,sp

	move.w	d0,oldrez	;Sauvegarder l'ancienne résolution

	move.l	#oldpal,a3	;Buffer pour ancienne palette
	moveq	#0,d3		;Commencer avec la couleur 0

loopcol:
	move.w	#-1,-(sp)	;Lire la couleur
	move.w	d3,-(sp)	;Numéro de couleur
	move.w	#7,-(sp)	;Setcolor
	trap	#14		;XBIOS
	addq.l	#6,sp

	move.w	d0,(a3)+	;Sauvegarder la couleur

	addq.w	#1,d3		;Couleur suivante

	cmp.w	#16,d3		;A-t-on traité les 16 couleurs ?
	blt	loopcol		;Non

	rts

;--------------------------------------------------------------------------
; Restaurer le mode vidéo
;--------------------------------------------------------------------------
restoremode:
	move.w	oldrez,-(sp)	;Restaurer l'ancienne résolution
	move.l	#-1,-(sp)	;Ne pas changer l'adresse physique
	move.l	#-1,-(sp)	;Ne pas changer l'adresse logique
	move.w	#5,-(sp)	;Setscreen
	trap	#14		;XBIOS
	add.l	#12,sp

	move.l	#oldpal,-(sp)	;Restaurer l'ancienne palette
	move.w	#6,-(sp)	;Setpalette
	trap	#14		;XBIOS
	addq.l	#6,sp

	rts

;--------------------------------------------------------------------------
; Données
;--------------------------------------------------------------------------

pi1:
	INCBIN	xenon.pi1

;--------------------------------------------------------------------------
; Variables
;--------------------------------------------------------------------------

	SECTION	BSS

oldrez:
	DS.W	1	;Ancienne résolution

oldpal:
	DS.W	16	;Ancienne palette
