; generic macros

; start a bank section; subsequent %org() addresses are 16-bit within this bank
macro bank(b)
    !bank = <b>
endmacro

; org to a 16-bit address within the current bank (see %bank)
macro org(addr)
    org (!bank<<16)|<addr>
endmacro

macro bge(target)
    bcs <target>
endmacro

macro blt(target)
    bcc <target>
endmacro
