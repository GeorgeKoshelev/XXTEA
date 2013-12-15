.386 

option casemap:none

;����� ������ ����������, ��� �������������� � �������� ��������
INCLUDE Irvine32.inc


;����: e,z,y,sum
;�����: ecx =  (((z>>5)^(y<<2))+((y>>3)^(z<<4)))^((sum^y)+(k[(p&3)^e]^z))

MX macro e, z, y, sum
    mov     ecx , [z]
    shr     ecx , 5         ; z>>5
    mov     edx , [y]
    shl     edx , 2         ; y<<2
    xor     ecx , edx       ; ��������� (z>>5)^(y<<2)
    mov     eax , [y]
    shr     eax , 3         ; y>>3
    mov     edx , [z]
    shl     edx , 4         ; z<<4
    xor     eax , edx       ; ��������� (y>>3)^(z<<4)
    add     ecx , eax       ; ��������� ((z>>5)^(y<<2))+((y>>3)^(z<<4))
    mov     eax , [sum]
    xor     eax , [y]       ; ��������� (sum^y)
    mov     edx , [p]
    and     edx , 3         ; ��������� (p&3)
    xor     edx , [e]       ; (p&3)^e
    mov     esi , offset key
    mov     edx , [esi+edx*4] ; edx = k[(p&3)^e]
    xor     edx , [z]         ; k[(p&3)^e]^z
    add     eax , edx         ; (sum^y)+(k[(p&3)^e]^z)
    xor     ecx , eax         ; ((z>>5)^(y<<2))+((y>>3)^(z<<4)))^((sum^y)+(k[(p&3)^e]^z)) 
endm

.const

BUFFER_SIZE     equ     65535   ; ��������� ������������ ������ ������� ������ 65535 �������
DELTA           equ     -1640531527 ; DELTA 

.data
key             BYTE    16          DUP(0)  ;   ������ �����. ����� ����� = 16 ���� = 128 ���
data            BYTE    BUFFER_SIZE DUP(0)  ;   ������ ������� ������

inputFileName   BYTE    "input",0   ; ��������� �������� ����� � �������� �������
keyFileName     BYTE    "key",0     ; ��� ����� � ������
outputFileName  BYTE    "output",0  ; �������� ����� ��� ������ ����������


error           BYTE        0       ; ��������� ��� ����������� �� �������� �� ����� ������ � �������� ��������. ���� error != 0 ��������� ������
bytesRead       DWORD       0       ; ���������� ����������� ����
bytesWritten    DWORD       16      ; ���������� ���������� ����

;���� ����������� ��������� ������
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

	;���������� ������� ������������ �� ������� 6+52/n
    .if [n] > 52
        mov [rounds] , 6        ; ���� n>52 ����� (52/n < 1) => ����� ��������� ��� ���������
    .else
        mov     ecx , 6
        mov     eax , 52
        mov     ebx , [n]
        and     ebx , 0ffh
        div     bl
        add     cl , al
        xor     eax , eax
        mov     al , cl
        mov     rounds , eax    ; ��������� ���������� �������
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


;������� ������ ����� �� ����� key
ReadXxteaKey PROC
    LOCAL   fileHandle : HANDLE
    mov     edx , OFFSET keyFileName
    invoke  OpenInputFile               ; ������� ����
    mov     fileHandle , eax            ; ������ � fileHandle ����� ������� ��� ����� key
    .if eax == INVALID_HANDLE_VALUE     ; �������� ���������� �� �������
        mov     error , 1               ; ������� ������, ��� ���� ������
        mov     edx , OFFSET fileOpenError
        call    WriteString             ; ���������� ������ �� �������
        ret                             ; � ������
    .endif
    mov     edx , OFFSET key
    mov     ecx , 16                    ; �������, ��� ���� ������ 16 ����
    call    ReadFromFile                ; � ������� �������
    .if eax !=  16                      ; �������� ��������� �� 16 ����
        mov     error , 1               ; ���� ��� - ������ ������, ��� ��������� ������
        mov     edx , offset BadKeyError
        call    WriteString             ; ���������� ������ � �������
    .endif
    mov     eax , fileHandle
    call    CloseFile                   ;����� ������� ������� � ������
    ret
ReadXxteaKey endp

;������� ������ ������ �� �����
ReadXxteaData   PROC
    LOCAL   fileHandle : HANDLE
    mov     edx , OFFSET inputFileName
    invoke  OpenInputFile               ; ������� ����
    mov     fileHandle , eax            ; ������ � fileHandle ����� ������� ��� ����� input
    .if eax == INVALID_HANDLE_VALUE     ; �������� ���������� �� �������
        mov     error , 1               ; ������� ������, ��� ���� ������
        mov     edx , OFFSET fileOpenError
        call    WriteString             ; ���������� ������ �� �������
        ret                             ; � ������
    .endif
    mov     edx , OFFSET data
    mov     ecx , BUFFER_SIZE
    call    ReadFromFile                ; ������ �� ����� ��-���������, �� �� ������ BUFFER_SIZE
    .if eax == 0                        ; �������� ������� ���� ���������
        mov     error , 1               ; ���� 0, ������� ������, ��� ���� ������
        mov     edx , offset dataError
        call    WriteString             ; ���������� �� �� �������
        ret                             ; � ������
    .endif
    
    .if eax < 8
        mov     bytesRead , 8           ; ������ �� ������ ���� �� ������ 64 ���
    .else
        mov     bytesRead , eax
        xor     edx , edx
        mov     ecx , 4
        div     ecx
        sub     ecx , edx               ; ������ �� ������ ���� ������ 4
        .if ecx != 4
            add     bytesRead , ecx
        .endif
    .endif
    ret
ReadXxteaData   endp

;������� ������ ������ � ����
WriteXxteaResult    PROC
    LOCAL fileHandle : HANDLE

    INVOKE CreateFile, ADDR outputFileName, GENERIC_WRITE, DO_NOT_SHARE, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0  ; �������� ����
    mov     fileHandle , eax            ; ������ � fileHandle ����� ������� ��� ����� output
    .if eax == INVALID_HANDLE_VALUE     ; �������� ���������� �� �������
        mov     edx , offset fileCreateError
        call    WriteString             ; ���������� ������ �� �������
        ret                             ; � ������
    .endif
    INVOKE WriteFile, fileHandle,ADDR data,bytesRead,ADDR bytesWritten,0    ; ������� ��������� � ����
    INVOKE CloseHandle, fileHandle                                          ; ������� �������
    ret                                                                     ; � ������
WriteXxteaResult    endp

main PROC
    call    ReadXxteaKey    ; ��������� ����
    .if error != 0          ; �������� ���������� ��� ���
        ret
    .endif
    call    ReadXxteaData   ; ������ ������� ������
    .if error != 0          ; �������� ����������� ��� ���
        ret
    .endif
    mov     eax , [bytesRead]
    shr     eax , 2         ; ��������� ����� � ����� �������� �� 4
    invoke  XxteaEncode , ADDR data , eax   ; ����� ������� ����������
    call    WriteXxteaResult    ; ������� ��������� � ����
    exit
main ENDP

END main    