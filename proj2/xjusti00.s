; Vernamova sifra na architekture DLX
; Matus Justik xjusti00
; xjusti00-r1-r6-r9-r25-r29-r0

        .data 0x04          ; zacatek data segmentu v pameti
login:  .asciiz "xjusti00"  ; <-- nahradte vasim loginem
cipher: .space 9 ; sem ukladejte sifrovane znaky (za posledni nezapomente dat 0)

        .align 2            ; dale zarovnavej na ctverice (2^2) bajtu
laddr:  .word login         ; 4B adresa vstupniho textu (pro vypis)
caddr:  .word cipher        ; 4B adresa sifrovaneho retezce (pro vypis)

        .text 0x40          ; adresa zacatku programu v pameti
        .global main        ; 
		
main:
	addi r25, r0, 97	;hodnota pisemna a
	addi r29, r0, 122	;hodnota pismena z
	addi r6, r0, 0		;r6 = 0, bude sluzit ako counter, r0 vzdy bude 0

letter:
	lb r9, login(r6)	;nacitanie znaku 
	sgt r1, r25, r9 	;ak r25>r9 tak r1=1 inak r1=0
	bnez r1, number		;ak r1!=0 chod na navestie 
	addi r9, r9, 10		;r9+10 (pismeno j s hodonotou 10)
	sgt r1, r9, r29		;ak r9>r29 tak r1=1 inak r1=0
	bnez r1, minus		;ak r1!=0 chod na navestie 

minuscontinue:	;navestie na pokracovanie programu po vykoni minus
	sb cipher(r6), r9	;ulozenie
	addi r6, r6, 1		;r6++
	lb r9, login(r6)	;nacitaj pismenko s hodnotou r6++
	sgt r1, r25, r9 	;if r25>r9 then r1=1 else r1 = 0
	bnez r1, number		;ak r1!=0 chod na navestie 
	subi r9, r9, 21		;r9+21(pismeno u s hodonotu 21)
	sgt r1, r25, r9		;ak r25>r9 tak r1=1 inak r1=0
	bnez r1, plus		;ak r1!=0 chod na navestie 

pluscontinue:	;navestie na pokracovanie programu po vykoni plus
	sb cipher(r6), r9	;ulozenie
	addi r6, r6, 1		;r6++
	j letter		;jump

minus:	;posun ak pismenko bude mimo rozhranie a-z
	nop		
	nop
	subi r9, r9, 26		;odcitam hodnotu pismena z (26)
	j minuscontinue		;jump

plus: 	;posun ak pismenko bude mimo rozhranie a-z
	nop
	nop
	addi r9, r9, 26		;pripocitam hodnotu pismena z (26)
	j pluscontinue		;jump

number:	;naslo sa cislo ulozi sa nula a koniec programu
	nop
	nop
	addi r6, r6, 1		;r6++
	addi r9, r0, 0		;r9 = 0
	sb cipher(r6), r9


end:    addi r14, r0, caddr ; <-- pro vypis sifry nahradte laddr adresou caddr
        trap 5  ; vypis textoveho retezce (jeho adresa se ocekava v r14)
        trap 0  ; ukonceni simulace
