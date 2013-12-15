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

;Функция, выполняющая операцию расшифрования
;Входные параметры - pointer - указатель на массив с шифротекстом (ШТ) , n - количество блоков ШТ
XxteaDecode PROC uses ebx v: DWORD, n:DWORD
    LOCAL   y : DWORD
    LOCAL   z : DWORD
    LOCAL   sum : DWORD
    LOCAL   p : DWORD
    LOCAL   rounds: DWORD
    LOCAL   e : DWORD
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
    mov     ecx , [rounds]
    imul    ecx , DELTA
    mov     [sum] , ecx         ; sum = rounds*DELTA
    mov     edx , [v]
    mov     eax , [edx]
    mov     [y] , eax           ; y = v[0]
mainLoop:
    mov     ecx , [sum]
    shr     ecx , 2
    and     ecx , 3
    mov     [e] , ecx           ; e = (sum >> 2) & 3
    mov     edx , [n]
    dec     edx
    mov     [p] , edx           ; p=n-1
    jmp     short   innerLoopBody
mainLoopBody1:                         ;внутренний цикл
    mov     eax , [p]
    dec     eax
    mov     [p] , eax                   ; уменьшаем p
innerLoopBody:                          ; тело внутреннего цикла
    cmp     [p] , 0                     ; пока p!=0 будем вычислять z = v[p-1], y = v[p] -= MX, в противном случае возвращаемся в внешний цикл
    jbe     short   mainLoopBody2
    mov     ecx , [p]
    dec     ecx                         ; p-1
    mov     edx , [v]
    mov     eax , [edx+ecx*4]           ; v[p-1]
    mov     [z] , eax                   ; z = v[p-1]
    MX e, z, y, sum                     ; вычислим MX , получим в ecx результат
    mov     eax , [p]
    mov     edx , [v]
    mov     ebx , dword ptr [edx+eax*4] 
    sub     ebx , ecx                   ; v[p]-MX
    mov     DWORD PTR [edx+eax*4], ebx  ; v[p] = v[p] - MX
    mov     [y] , ebx                   ; y = v[p] - MX
    jmp     short   mainLoopBody1
mainLoopBody2:
    mov     edx , [n]
    dec     edx                         ; n-1
    mov     eax , [v]
    mov     ecx , dword ptr [eax+edx*4]
    mov     [z] , ecx                   ; z = v[n-1]
    MX e, z, y, sum                     ; вычислим MX , получим в ecx результат
    mov     edx , [v]
    mov     eax , dword ptr [edx]
    sub     eax , ecx                   ; v[0]-MX
    mov     dword ptr [edx], eax        ; v[0] = v[0]-MX
    mov     [y] , eax                   ; y = v[0]
    mov     ecx , [sum]
    sub     ecx , DELTA
    mov     [sum] , ecx                 ; sum -= DELTA
    jne mainLoop

	ret
XxteaDecode	endp

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
    invoke  XxteaDecode , ADDR data , eax   ; вызов функции декодирования
    call    WriteXxteaResult    ; запишем результат в файл
    exit
main ENDP

END main