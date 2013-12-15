.386 

option casemap:none

;очень нужная библиотека, для взаимодействия с файловой системой
INCLUDE Irvine32.inc


;Вход: e,z,y,sum
;Выход: ecx =  (((z>>5)^(y<<2))+((y>>3)^(z<<4)))^((sum^y)+(k[(p&3)^e]^z))

MX macro e, z, y, sum
    mov     ecx , [z]
    shr     ecx , 5         ; z>>5
    mov     edx , [y]
    shl     edx , 2         ; y<<2
    xor     ecx , edx       ; вычислили (z>>5)^(y<<2)
    mov     eax , [y]
    shr     eax , 3         ; y>>3
    mov     edx , [z]
    shl     edx , 4         ; z<<4
    xor     eax , edx       ; вычислили (y>>3)^(z<<4)
    add     ecx , eax       ; вычислили ((z>>5)^(y<<2))+((y>>3)^(z<<4))
    mov     eax , [sum]
    xor     eax , [y]       ; вычислили (sum^y)
    mov     edx , [p]
    and     edx , 3         ; вычислили (p&3)
    xor     edx , [e]       ; (p&3)^e
    mov     esi , offset key
    mov     edx , [esi+edx*4] ; edx = k[(p&3)^e]
    xor     edx , [z]         ; k[(p&3)^e]^z
    add     eax , edx         ; (sum^y)+(k[(p&3)^e]^z)
    xor     ecx , eax         ; ((z>>5)^(y<<2))+((y>>3)^(z<<4)))^((sum^y)+(k[(p&3)^e]^z)) 
endm

.const

BUFFER_SIZE     equ     65535   ; ограничим максимальный размер входных данных 65535 байтами
DELTA           equ     -1640531527 ; DELTA 

.data
key             BYTE    16          DUP(0)  ;   буффер ключа. длина ключа = 16 байт = 128 бит
data            BYTE    BUFFER_SIZE DUP(0)  ;   буффер входных данных

inputFileName   BYTE    "input",0   ; определим название файла с входными данными
keyFileName     BYTE    "key",0     ; имя файла с ключом
outputFileName  BYTE    "output",0  ; название файла для записи вычислений


error           BYTE        0       ; переменна для мониторинга за ошибками во время работы с файловой системой. если error != 0 произошла ошибка
bytesRead       DWORD       0       ; количество прочитанных байт
bytesWritten    DWORD       16      ; количество записанных байт

;ниже перечислены различные ошибки
fileCreateError     BYTE    "Error: failed to create file",0dh,0ah,0
fileOpenError       BYTE    "Error: failed to open file",0dh,0ah,0
BadKeyError         BYTE    "Error: key length is wrong",0dh,0ah,0
dataError           BYTE    "Error: data file is empty",0dh,0ah,0

.code

XxteaEncode     PROC uses ebx v: DWORD, n:DWORD
    LOCAL y : DWORD
    LOCAL z : DWORD
    LOCAL sum : DWORD
    LOCAL p : DWORD
    LOCAL rounds: DWORD
    LOCAL e : DWORD

	;количество раундов определяется по формуле 6+52/n
    .if [n] > 52
        mov [rounds] , 6        ; если n>52 тогда (52/n < 1) => можно отбросить это слагаемое
    .else
        mov     ecx , 6
        mov     eax , 52
        mov     ebx , [n]
        and     ebx , 0ffh
        div     bl
        add     cl , al
        xor     eax , eax
        mov     al , cl
        mov     rounds , eax    ; вычислили количество раундов
    .endif

    mov     [sum] , 0           ; sum = 0

    mov     eax , [n]
    dec     eax
    mov     ecx , [v]
    mov     edx , [ecx+eax*4]
    mov     [z] , edx           ; z=v[n-1]

mainLoop:
    mov     eax , [sum]
    add     eax , DELTA
    mov     [sum] , eax             ; sum += DELTA
    shr     eax , 2
    and     eax , 3
    mov     [e] , eax               ; e = (sum >> 2) & 3
    mov     [p] , 0                 ; p = 0
    jmp     short   innerLoop
mainLoopBody1:
    inc dword ptr [p]
innerLoop:
    mov     eax , [n]
    dec     eax
    cmp     [p] , eax
    jae     mainLoopBody2
    mov     ecx, [p]
    inc     ecx
    mov     edx, [v]
    mov     eax, dword ptr [edx+ecx*4]
    mov     dword ptr [y], eax              ; y = v[p+1]
    MX e, z, y, sum
    mov     eax , [p]
    mov     edx , [v]
    mov     ebx, dword ptr [edx+eax*4]
    add     ebx, ecx
    mov     dword ptr [edx+eax*4] , ebx     ; v[p] += MX
    mov     [z] , ebx                       ; z = v[p]
    jmp     mainLoopBody1
mainLoopBody2:
    mov     edx , [v]
    mov     eax , dword ptr [edx]
    mov     [y] , eax                       ; y = v[0]
    MX e, z, y, sum
    mov     eax , [n]
    dec     eax
    mov     edx , [v]
    mov     ebx , [edx+eax*4]               ; ebx = v[n-1]
    add     ebx , ecx
    mov     [edx+eax*4] , ebx               ; v[n-1] = v[n-1]+MX
    mov     [z] , ebx                       ; z = v[n-1]
    dec     [rounds]
    jne     mainLoop
    ret
XxteaEncode	endp


;функция чтения ключа из файла key
ReadXxteaKey PROC
    LOCAL   fileHandle : HANDLE
    mov     edx , OFFSET keyFileName
    invoke  OpenInputFile               ; откроем файл
    mov     fileHandle , eax            ; теперь в fileHandle лежит хэндлер для файла key
    .if eax == INVALID_HANDLE_VALUE     ; проверим нормальный ли хэндлер
        mov     error , 1               ; сообщим наверх, что была ошибка
        mov     edx , OFFSET fileOpenError
        call    WriteString             ; напечатаем ошибку на консоль
        ret                             ; и выйдем
    .endif
    mov     edx , OFFSET key
    mov     ecx , 16                    ; сообщим, что надо читать 16 байт
    call    ReadFromFile                ; и позовем читалку
    .if eax !=  16                      ; проверим считались ли 16 байт
        mov     error , 1               ; если нет - сообщи наверх, что произошла ошибка
        mov     edx , offset BadKeyError
        call    WriteString             ; напечатать ошибку в консоль
    .endif
    mov     eax , fileHandle
    call    CloseFile                   ;иначе закроем хэндлер и выйдем
    ret
ReadXxteaKey endp

;функция чтения данных из файла
ReadXxteaData   PROC
    LOCAL   fileHandle : HANDLE
    mov     edx , OFFSET inputFileName
    invoke  OpenInputFile               ; откроем файл
    mov     fileHandle , eax            ; теперь в fileHandle лежит хэндлер для файла input
    .if eax == INVALID_HANDLE_VALUE     ; проверим нормальный ли хэндлер
        mov     error , 1               ; сообщим наверх, что была ошибка
        mov     edx , OFFSET fileOpenError
        call    WriteString             ; напечатаем ошибку на консоль
        ret                             ; и выйдем
    .endif
    mov     edx , OFFSET data
    mov     ecx , BUFFER_SIZE
    call    ReadFromFile                ; читаем из файла по-максимуму, но не больше BUFFER_SIZE
    .if eax == 0                        ; проверим сколько байт считалось
        mov     error , 1               ; если 0, сообщим наверх, что была ошибка
        mov     edx , offset dataError
        call    WriteString             ; напечатаем ее на консоль
        ret                             ; и выйдем
    .endif
    
    .if eax < 8
        mov     bytesRead , 8           ; размер ОТ должен быть не меньше 64 бит
    .else
        mov     bytesRead , eax
        xor     edx , edx
        mov     ecx , 4
        div     ecx
        sub     ecx , edx               ; размер ОТ должен быть кратен 4
        .if ecx != 4
            add     bytesRead , ecx
        .endif
    .endif
    ret
ReadXxteaData   endp

;функция записи данных в файл
WriteXxteaResult    PROC
    LOCAL fileHandle : HANDLE

    INVOKE CreateFile, ADDR outputFileName, GENERIC_WRITE, DO_NOT_SHARE, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0  ; создадим файл
    mov     fileHandle , eax            ; теперь в fileHandle лежит хэндлер для файла output
    .if eax == INVALID_HANDLE_VALUE     ; проверим нормальный ли хэндлер
        mov     edx , offset fileCreateError
        call    WriteString             ; напечатаем ошибку на консоль
        ret                             ; и выйдем
    .endif
    INVOKE WriteFile, fileHandle,ADDR data,bytesRead,ADDR bytesWritten,0    ; запишем результат в файл
    INVOKE CloseHandle, fileHandle                                          ; закроем хэндлер
    ret                                                                     ; и выйдем
WriteXxteaResult    endp

main PROC
    call    ReadXxteaKey    ; прочитаем ключ
    .if error != 0          ; проверим прочитался или нет
        ret
    .endif
    call    ReadXxteaData   ; читаем входные данные
    .if error != 0          ; проверим прочитались или нет
        ret
    .endif
    mov     eax , [bytesRead]
    shr     eax , 2         ; переведем байты в блоки делением на 4
    invoke  XxteaEncode , ADDR data , eax   ; вызов функции шифрования
    call    WriteXxteaResult    ; запишем результат в файл
    exit
main ENDP

END main    