# shellcheck shell=bash
# Pure-bash case conversion helpers for lib/core/.
# Replaces external case conversion commands so core modules remain
# free of external system commands.

# case_to_upper converts its argument to uppercase using a character-by-character
# case statement. Correct for ASCII; non-alpha characters pass through unchanged.
case_to_upper() {
    local _result='' _i _ch
    for (( _i=0; _i<${#1}; _i++ )); do
        _ch="${1:_i:1}"
        case "${_ch}" in
            a) _ch=A ;; b) _ch=B ;; c) _ch=C ;; d) _ch=D ;; e) _ch=E ;;
            f) _ch=F ;; g) _ch=G ;; h) _ch=H ;; i) _ch=I ;; j) _ch=J ;;
            k) _ch=K ;; l) _ch=L ;; m) _ch=M ;; n) _ch=N ;; o) _ch=O ;;
            p) _ch=P ;; q) _ch=Q ;; r) _ch=R ;; s) _ch=S ;; t) _ch=T ;;
            u) _ch=U ;; v) _ch=V ;; w) _ch=W ;; x) _ch=X ;; y) _ch=Y ;;
            z) _ch=Z ;;
        esac
        _result+="${_ch}"
    done
    printf '%s' "${_result}"
}

# case_to_lower converts its argument to lowercase.
case_to_lower() {
    local _result='' _i _ch
    for (( _i=0; _i<${#1}; _i++ )); do
        _ch="${1:_i:1}"
        case "${_ch}" in
            A) _ch=a ;; B) _ch=b ;; C) _ch=c ;; D) _ch=d ;; E) _ch=e ;;
            F) _ch=f ;; G) _ch=g ;; H) _ch=h ;; I) _ch=i ;; J) _ch=j ;;
            K) _ch=k ;; L) _ch=l ;; M) _ch=m ;; N) _ch=n ;; O) _ch=o ;;
            P) _ch=p ;; Q) _ch=q ;; R) _ch=r ;; S) _ch=s ;; T) _ch=t ;;
            U) _ch=u ;; V) _ch=v ;; W) _ch=w ;; X) _ch=x ;; Y) _ch=y ;;
            Z) _ch=z ;;
        esac
        _result+="${_ch}"
    done
    printf '%s' "${_result}"
}
