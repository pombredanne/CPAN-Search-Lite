package CPAN::Search::Lite::Lang;
use strict;
use warnings;

use base qw(Exporter);
our (@EXPORT_OK, %na, %bytes, $chaps_desc, %langs, $pages,
     $dslip, $months);
@EXPORT_OK = qw(%na $chaps_desc %bytes %langs $pages
                $dslip $months);

%na = (
       de => 'nicht spezifiziert',
       fr => 'non pr&eacute;cis&eacute;',
       en => 'not specified',
       es => 'no especificado',
       it => 'non specificato',
      );

%bytes = (
       de => 'Bytes',
       fr => 'octets',
       en => 'bytes',
       es => 'byte',
       it => 'byte',
      );

make_langs();

$chaps_desc = {
    de => {
        2 => q{Perl Kernmodule},
        3 => q{Entwicklungsunterst&uuml;tzung},
        4 => q{Betriebssystem-Schnittstellen},
        5 => q{Netzwerke Devices IPC},
        6 => q{Datentyp-Utilities},
        7 => q{Datenbankschnittstellen},
        8 => q{Benutzerschnittstellen},
        9 => q{Sprachenschnittstellen},
        10 => q{Dateinamen System Locking},
        11 => q{Strings Sprachen Text Proc},
        12 => q{Optionen Argumente Parameter Proc},
        13 => q{Internationalisierung Lokalisierung},
        14 => q{Sicherheit und Verschl&uuml;sselung},
        15 => q{World Wide Web HTML HTTP Cgi},
        16 => q{Server D&auml;monen},
        17 => q{Archivierung und Kompression},
        18 => q{Bilder Pixmaps Bitmaps},
        19 => q{eMail und Usenet},
        20 => q{Kontrollflu&szlig;-Utilities},
        21 => q{Dateihandles Input Output},
        22 => q{Microsoft Windows Module},
        23 => q{Verschiedene Module},
        24 => q{Kommerzielle Programmschnittstellen},
        99 => q{Noch nicht katalogisiert},
    },
    en => {
        2 => q{Perl Core Modules},
        3 => q{Development Support},
        4 => q{Operating System Interfaces},
        5 => q{Networking Devices IPC},
        6 => q{Data Type Utilities},
        7 => q{Database Interfaces},
        8 => q{User Interfaces},
        9 => q{Language Interfaces},
        10 => q{File Names Systems Locking},
        11 => q{String Lang Text Proc},
        12 => q{Opt Arg Param Proc},
        13 => q{Internationalization Locale},
        14 => q{Security and Encryption},
        15 => q{World Wide Web HTML HTTP CGI},
        16 => q{Server and Daemon Utilities},
        17 => q{Archiving and Compression},
        18 => q{Images Pixmaps Bitmaps},
        19 => q{Mail and Usenet News},
        20 => q{Control Flow Utilities},
        21 => q{File Handle Input Output},
        22 => q{Microsoft Windows Modules},
        23 => q{Miscellaneous Modules},
        24 => q{Commercial Software Interfaces},
        99 => q{Not Yet In Modulelist},
    },
    es => {
        2 => q{M&oacute;dulos b&aacute;sicos del Perl},
        3 => q{Ayuda para el desarrollo},
        4 => q{Interfaces con el Sistema Operativo},
        5 => q{Servicios red IPC},
        6 => q{Utilidades de estructuras de datos},
        7 => q{Interfaces de bases de datos},
        8 => q{Interfaces del usuario},
        9 => q{Interfaces de lenguajes},
        10 => q{Sistemas de ficheros},
        11 => q{Procesamiento de textos},
        12 => q{Procesamiento de argumentos y opciones},
        13 => q{Configuraciones regionales},
        14 => q{Seguridad y cifrado},
        15 => q{World Wide Web HTML HTTP CGI},
        16 => q{Servidores y demonios},
        17 => q{Archivando y comprimiendo},
        18 => q{Im&aacute;genes y Bitmaps},
        19 => q{Correo electr&oacute;nico y News},
        20 => q{Utilidades de control de flujo},
        21 => q{Ficheros. Entrada/Salida},
        22 => q{M&oacute;dulos de Microsoft Windows},
        23 => q{M&oacute;dulos varios},
        24 => q{Interfaces de Software Comercial},
        99 => q{No todav&iacute;a en lista de m&oacute;dulos},
    },
    fr => {
        2 => q{Modules du noyau Perl},
        3 => q{Aide au d&eacute;veloppement},
        4 => q{Interfaces du syst&egrave;me d'exploitation},
        5 => q{P&eacute;riph&eacute;riques r&eacute;seau, IPC},
        6 => q{Types de donn&eacute;es},
        7 => q{Interfaces de bases de donn&eacute;es},
        8 => q{Interfaces utilisateur},
        9 => q{Interfaces vers d'autres langages},
        10 => q{Fichiers, Syst&egrave;mes de fichiers, verrouillage},
        11 => q{String, Lang, Text, Proc},
        12 => q{Opt, Arg, Param, Proc},
        13 => q{Param&egrave;tres de lieu et internationalisation},
        14 => q{S&eacute;curit&eacute; et chiffrement},
        15 => q{World Wide Web, HTML, HTTP, CGI},
        16 => q{Serveurs et d&eacute;mons},
        17 => q{Archivage et compression},
        18 => q{Images, Pixmaps, Bitmaps},
        19 => q{Courriel et forums Usenet},
        20 => q{Utilitaires de flux de commande},
        21 => q{Descripteurs de fichier, Entr&eacute;es, Sorties},
        22 => q{Modules pour Microsoft Windows},
        23 => q{Modules divers},
        24 => q{Interfaces pour logiciels commerciaux},
        99 => q{Pas encore dans la liste des modules},
    },
    it => {
        2 => q{Moduli Core Perl},
        3 => q{Supporto per lo Sviluppo},
        4 => q{Interfacce per Sistemi Operativi},
        5 => q{Dispositivi di Rete e IPC},
        6 => q{Programmi di utilit&agrave; per Tipi di Dato},
        7 => q{Interfacce per Database},
        8 => q{Interfacce Utente},
        9 => q{Interfacce per Linguaggi},
        10 => q{File, File Systems, File Locking},
        11 => q{Elaborazione di Stringhe, Linguaggi e Testi},
        12 => q{Parametri, Argomenti, Opzioni e File di Configurazione},
        13 => q{Internazionalizzazione e Localizzazione},
        14 => q{Sicurezza e Crittografia},
        15 => q{World Wide Web HTML HTTP CGI},
        16 => q{Programmi di Utilit&agrave; per Demoni e Server},
        17 => q{Archiviazione e Compressione},
        18 => q{Immagini Pixmap Bitmap},
        19 => q{Posta e Newsgroup Usenet},
        20 => q{Programmi di utilit&agrave; per il Controllo di Flusso},
        21 => q{Filehandle Input Output},
        22 => q{Moduli per Microsoft Windows},
        23 => q{Moduli Vari},
        24 => q{Interfacce per Software Commerciali},
        99 => q{Non Ancora in Modulelist},
    },
};

$dslip = {
  de => {
    d => {
      M => q{Ausgereift},
      R => q{Freigegeben},
      S => q{Standard, geliefert mit Perl 5},
      a => q{Alphaphase},
      b => q{Betaphase},
      c => q{Pre-alpha Stadium (noch nicht freigegeben)},
      desc => q{Entwicklungsstatus (Anmerkung: * IMPLIZIERT KEINE ZEITSKALA *)},
      i => q{Idee - nur zur Koordination oder als Platzhalter verzeichnet},
    },
    s => {
      a => q{Aufgegeben, Autor k&uuml;mmert sich nicht mehr um sein Modul},
      d => q{Entwickler},
      desc => q{Support Level},
      m => q{Mailingliste},
      n => q{Unbekannt, m&ouml;glicherweise &uuml;ber comp.lang.perl.modules},
      u => q{Usenet: comp.lang.perl.modules},
    },
    l => {
      '+' => q{C++ und Perl, C++ Compiler erforderlich},
      c => q{C und Perl, C Compiler erforderlich},
      desc => q{Verwendete Sprache(n)},
      h => q{Hybrid, geschrieben in Perl mit optionalem C Code, Compiler nicht ben&ouml;tigt},
      o => q{Perl und weitere Sprache (weder C noch C++)},
      p => q{Perl, kein Compiler n&ouml;tig, sollte plattformunabh&auml;ngig sein},
    },
    i => {
      O => q{Objektorientiert mit Blessed References und/oder Vererbung},
      desc => q{Art der Schnittstelle},
      f => q{Normale Funktionen, keine Referenzen},
      h => q{Hybrid, objektorientierte und funktionale Schnittstellen vorhanden},
      n => q{Keinerlei Schnittstelle (nanu?)},
      r => q{Unblessed References oder Ties},
    },
    p => {
      a => q{Artistic License},
      b => q{BSD: Die BSD Lizenz},
      desc => q{Lizenz},
      g => q{GPL: Gnu Public License},
      l => q{LGPL: "GNU Lesser General Public License" (fr&uuml;her bekannt als "GNU Library General Public License")},
      o => q{Andere Lizenz (Verteilung unbeschr&auml;nkt erlaubt)},
      p => q{Standard-Perl: Freie Wahl zwischen GPL und Artistic License},
    },
  },
  en => {
    d => {
      M => q{Mature (no rigorous definition)},
      R => q{Released},
      S => q{Standard, supplied with Perl 5},
      a => q{Alpha testing},
      b => q{Beta testing},
      c => q{Under construction but pre-alpha (not yet released)},
      desc => q{Development Stage (Note: *NO IMPLIED TIMESCALES*)},
      i => q{Idea, listed to gain consensus or as a placeholder},
    },
    s => {
      a => q{Abandoned, the module has been abandoned by its author},
      d => q{Developer},
      desc => q{Support Level},
      m => q{Mailing-list},
      n => q{None known, try comp.lang.perl.modules},
      u => q{Usenet newsgroup comp.lang.perl.modules},
    },
    l => {
      '+' => q{C++ and perl, a C++ compiler will be needed},
      c => q{C and perl, a C compiler will be needed},
      desc => q{Language Used},
      h => q{Hybrid, written in perl with optional C code, no compiler needed},
      o => q{perl and another language other than C or C++},
      p => q{Perl-only, no compiler needed, should be platform independent},
    },
    i => {
      O => q{Object oriented using blessed references and/or inheritance},
      desc => q{Interface Style},
      f => q{plain Functions, no references used},
      h => q{hybrid, object and function interfaces available},
      n => q{no interface at all (huh?)},
      r => q{some use of unblessed References or ties},
    },
    p => {
      a => q{Artistic license alone},
      b => q{BSD: The BSD License},
      desc => q{Public License},
      g => q{GPL: GNU General Public License},
      l => q{LGPL: "GNU Lesser General Public License" (previously known as "GNU Library General Public License")},
      o => q{other (but distribution allowed without restrictions)},
      p => q{Standard-Perl: user may choose between GPL and Artistic},
    },
  },
  es => {
    d => {
      M => q{Maduro (no es una definici&oacute;n rigurosa)},
      R => q{Liberado},
      S => q{Est&aacute;ndar, disponible con Perl 5},
      a => q{Alfa, en modo test},
      b => q{Beta, en modo test},
      c => q{Bajo construcci&oacute;n pero pre-alfa (todav&iacute;a no liberado)},
      desc => q{Estado del desarrollo (Nota: * NO IMPLICA TIEMPOS *)},
      i => q{Idea, enumerada para ganar consenso o como repositorio},
    },
    s => {
      a => q{Abandonado, el m&oacute;dulo ha sido abandonado por su autor},
      d => q{Desarrollador},
      desc => q{Nivel de soporte},
      m => q{Lista de correo},
      n => q{Nada conocido, intente comp.lang.perl.modules},
      u => q{Grupo de News comp.lang.perl.modules},
    },
    l => {
      '+' => q{C++ y Perl, un compilador de C++ ser&aacute; necesario},
      c => q{C y Perl, un compilador de C ser&aacute; necesario},
      desc => q{Lenguaje utilizado},
      h => q{H&iacute;brido, escrito en Perl con c&oacute;digo opcional en C, no se necesita compilador},
      o => q{Perl y otro lenguaje distinto de C o de C++},
      p => q{S&oacute;lo Perl, ning&uacute;n compilador necesario, debe ser independiente de la plataforma},
    },
    i => {
      O => q{Orientado a objetos utilizando referencias bendecidas y/o herencia},
      desc => q{Estilo del Interfaz},
      f => q{Funciones normales, no se utilizaron referencias},
      h => q{H&iacute;brido, existen objetos y funciones},
      n => q{Ninguna interfaz (&iquest;c&oacute;mo?)},
      r => q{alg&uacute;n uso de lazos o referencias no bendecidas},
    },
    p => {
      a => q{Licencia art&iacute;stica solamente},
      b => q{BSD: La licencia del BSD},
      desc => q{Licencia p&uacute;blica},
      g => q{GPL: Licencia P&uacute;blica General de GNU},
      l => q{LGPL: "Licencia Ligera P&uacute;blica General de GNU" (conocida previamente como "Licencia P&uacute;blica General de la librer&iacute;a del GNU")},
      o => q{otra (pero la distribuci&oacute;n est&aacute; permitida sin restricciones)},
      p => q{Perl est&aacute;ndar: el usuario puede elegir entre la GPL y la art&iacute;stica},
    },
  },
  fr => {
    d => {
      M => q{Stable (pas de d&eacute;finition pr&eacute;cise)},
      R => q{Distribu&eacute;},
      S => q{Standard, fourni avec Perl 5},
      a => q{Version alpha},
      b => q{Version b&ecirc;ta},
      c => q{En d&eacute;veloppement, version pr&eacute;-alpha (pas encore distribu&eacute;)},
      desc => q{Stade de d&eacute;veloppement (Note&nbsp;: * PAS DE CALENDRIER D&Eacute;TERMIN&Eacute; *)},
      i => q{Id&eacute;e, &agrave; d&eacute;battre ou simplement plac&eacute;e l&agrave; pour l'instant},
    },
    s => {
      a => q{Abandonn&eacute;, le module a &eacute;t&eacute; abandonn&eacute; par son auteur},
      d => q{D&eacute;veloppeur},
      desc => q{Niveau de support},
      m => q{Liste de diffusion},
      n => q{Inconnu, essayez comp.lang.perl.modules},
      u => q{Forum Usenet comp.lang.perl.modules},
    },
    l => {
      '+' => q{C++ et Perl, un compilateur C++ est n&eacute;cessaire},
      c => q{C et Perl, un compilateur C est n&eacute;cessaire},
      desc => q{Langage utilis&eacute;},
      h => q{Hybride, &eacute;crit en Perl avec du code C optionnel, pas besoin de compilateur},
      o => q{Perl et un langage autre que C ou C++},
      p => q{Perl uniquement, pas besoin de compilateur, a priori ind&eacute;pendant de plate-forme},
    },
    i => {
      O => q{Orient&eacute; objet, avec des r&eacute;f&eacute;rences b&eacute;nies et/ou de l'h&eacute;ritage},
      desc => q{Style d'interface},
      f => q{Fonctions simples, sans utilisation de r&eacute;f&eacute;rence},
      h => q{Interface hybride, orient&eacute;e objet et proc&eacute;durale},
      n => q{Aucune interface (hein ?)},
      r => q{Utilisation sporadique de r&eacute;f&eacute;rences non b&eacute;nies ou de r&eacute;f&eacute;rences li&eacute;es ("ties")},
    },
    p => {
      a => q{Licence artistique uniquement},
      b => q{BSD : Licence BSD},
      desc => q{Licence d'utilisation},
      g => q{GPL : Licence GPL ("GNU General Public License")},
      l => q{LGPL : Licence LGPL ("GNU Lesser General Public License") (pr&eacute;c&eacute;demment nomm&eacute;e "GNU Library General Public License")},
      o => q{Autre (mais la distribution est autoris&eacute;e sans restriction)},
      p => q{Licence Perl : l'utilisateur peut choisir entre les licences GPL et artistique},
    },
  },
  it => {
    d => {
      M => q{Maturo (nessuna definizione rigorosa)},
      R => q{Rilasciato},
      S => q{Standard, distribuito con il Perl 5},
      a => q{Versione alfa},
      b => q{Versione beta},
      c => q{In sviluppo come pre-alfa (non ancora rilasciato)},
      desc => q{Stadio Di Sviluppo (Nota: * NESSUNA SCALA CRONOLOGICA IMPLICITA *)},
      i => q{Idea, elencata per guadagnare consenso o come segnaposto},
    },
    s => {
      a => q{Abbandonato, il modulo &egrave; stato abbandonato dal suo autore},
      d => q{Sviluppatore},
      desc => q{Livello del Supporto},
      m => q{Mailing-List},
      n => q{Non noto, provare comp.lang.perl.modules},
      u => q{Newsgroup Usenet comp.lang.perl.modules},
    },
    l => {
      '+' => q{C++ e Perl, un compilatore C++ sar&agrave; necessario},
      c => q{C e Perl, un compilatore C sar&agrave; necessario},
      desc => q{Linguaggio Usato},
      h => q{Ibrido, scritto in Perl con parti di codice C opzionali, nessun compilatore &grave; necessario},
      o => q{Perl e un altro linguaggio tranne il C o il C++},
      p => q{Perl solamente, nessun compilatore &egrave; necessario, dovrebbe essere independente della piattaforma},
    },
    i => {
      O => q{Orientato agli Oggetti con utilizzo di riferimenti 'blessed' e/o ereditariet&agrave;},
      desc => q{Stile dell'Interfaccia},
      f => q{Solo Funzioni, senza utilizzo di riferimenti},
      h => q{Ibrido, interfacce ad oggetti e funzioni disponibili},
      n => q{Nessuna interfaccia (huh?)},
      r => q{Utilizzo di riferimenti non 'blessed' o di legami (tie)},
    },
    p => {
      a => q{Artistic License solamente},
      b => q{BSD: BSD License},
      desc => q{Licenza Pubblica},
      g => q{GPL: GNU General Public License},
      l => q{LGPL: "GNU Lesser General Public License" (in passato conosciuta come "GNU Library General Public License")},
      o => q{altro (ma la distribuzione &egrave; permessa senza limitazioni)},
      p => q{Perl Standard: l'utente pu&ograve; scegliere fra le licenze GPL ed Artistic},
    },
  },
};

$pages = {
  en => {  title => 'Browse and search CPAN',
           list => { module => 'Modules',
                    dist => 'Distributions',
                    author => 'Authors',
                  },
          buttons => {Home => 'Home',
                      Documentation => 'Documentation',
                      Recent => 'Recent',
                      Mirror => 'Mirror',
                      Modules => 'Modules',
                      Distributions => 'Distributions',
                      Authors => 'Authors',
                  },
           form => {Find => 'Find',
                    in => 'in',
                    Search => 'Search',
                   },
           Problems => 'Problems, suggestions, or comments to',
           Questions => 'Questions? Check the',
      },
  fr => {  title => 'Recherche et navigation sur CPAN',
           list => { module => 'Modules',
                    dist => 'Distributions',
                    author => 'Auteurs',
                  },
          buttons => {Home => 'Accueil',
                      Documentation => 'Documentation',
                      Recent => 'Nouveaut&eacute;s',
                      Mirror => 'Miroir',
                      Modules => 'Modules',
                      Distributions => 'Distributions',
                      Authors => 'Auteurs',
                  },
           form => {Find => 'Rechercher',
                    in => 'dans',
                    Search => 'Recherche',
                   },
           Problems => 'Envoyez vos probl&egrave;mes, suggestions ou commentaires &agrave;',
           Questions => 'Des questions&nbsp;? Lisez d\'abord la',
      },
 de => {  title => 'CPAN Browsen / Durchsuchen',
           list => { module => 'Modulen',
                    dist => 'Distributionen',
                    author => 'Autoren',
                  },
          buttons => {Home => 'Home',
                      Documentation => 'Dokumentation',
                      Recent => 'Neue Module',
                      Mirror => 'CPAN Mirrors',
                      Modules => 'Module',
                      Distributions => 'Distributionen',
                      Authors => 'Autoren',
                  },
           form => {Find => 'Suche',
                    in => 'in',
                    Search => 'Suchen',
                   },
           Problems => 'Probleme, Vorschl&auml;ge oder Anmerkungen bitte an',
           Questions => 'Fragen? Versuchen Sie mit der',
      },
 it => {  title => 'Naviga e cerca in CPAN',
           list => { module => 'Moduli',
                    dist => 'Distribuzioni',
                    author => 'Autori',
                  },
          buttons => {Home => 'Home',
                      Documentation => 'Documentazione',
                      Recent => 'Recenti',
                      Mirror => 'Mirror',
                      Modules => 'Moduli',
                      Distributions => 'Distribuzioni',
                      Authors => 'Autori',
                  },
           form => {Find => 'Cerca',
                    in => 'in',
                    Search => 'Trova',
                   },
           Problems => 'Problemi, suggerimenti o osservazioni a',
           Questions => 'Domande? Consulta le',
      },
  es => {  title => 'Hojear y buscar en CPAN',
           list => { module => 'M&oacute;dulos',
                    dist => 'Distribuciones',
                    author => 'Autores',
                  },
          buttons => {Home => 'Principal',
                      Documentation => 'Documentaci&oacute;n',
                      Recent => 'Recientes',
                      Mirror => 'Espejo',
                      Modules => 'M&oacute;dulos',
                      Distributions => 'Distribuciones',
                      Authors => 'Autores',
                  },
           form => {Find => 'Encontrar',
                    in => 'en',
                    Search => 'Buscar',
                   },
           Problems => 'Problemas, sugerencias, o comentarios a',
           Questions => '&iquest;Preguntas? Compruebe el',
      },
};

$months = {
  en => {'01' => 'Jan',
         '02' => 'Feb',
         '03' => 'Mar',
         '04' => 'Apr',
         '05' => 'May',
         '06' => 'June',
         '07' => 'July',
         '08' => 'Aug',
         '09' => 'Sep',
         '10' => 'Oct',
         '11' => 'Nov',
         '12' => 'Dec',
        },
  fr => {'01' => 'janv',
         '02' => 'f&eacute;vr',
         '03' => 'mars',
         '04' => 'avril',
         '05' => 'mai',
         '06' => 'juin',
         '07' => 'juil',
         '08' => 'ao&ucirc;t',
         '09' => 'sept',
         '10' => 'oct',
         '11' => 'nov',
         '12' => 'd&eacute;c',
        },
  es => {'01' => 'enero',
         '02' => 'feb',
         '03' => 'marzo',
         '04' => 'abr',
         '05' => 'mayo',
         '06' => 'jun',
         '07' => 'jul',
         '08' => 'agosto',
         '09' => 'sept',
         '10' => 'oct',
         '11' => 'nov',
         '12' => 'dic',
        },
  it => {'01' => 'Gennaio',
         '02' => 'Febbraio',
         '03' => 'Marzo',
         '04' => 'Aprile',
         '05' => 'Maggio',
         '06' => 'Giugno',
         '07' => 'Luglio',
         '08' => 'Agosto',
         '09' => 'Settembre',
         '10' => 'Ottobre',
         '11' => 'Novembre',
         '12' => 'Dicembre',
        },
  de => {'01' => 'J&auml;n',
         '02' => 'Feb',
         '03' => 'M&auml;rz',
         '04' => 'Apr',
         '05' => 'Mai',
         '06' => 'Juni',
         '07' => 'Juli',
         '08' => 'Aug',
         '09' => 'Sep',
         '10' => 'Okt',
         '11' => 'Nov',
         '12' => 'Dez',
        },
};

sub make_langs {
    %langs = map {$_ => 1} keys %na;
}

1;

__END__

=head1 NAME

CPAN::Search::Lite::Lang - export some common data structures used by CPAN::Search::Lite::*

=head1 DESCRIPTION

This module exports some common data structures used by other
I<CPAN::Search::Lite::*> modules. At present these are

=over 3

=item * C<$chaps_desc>

This is a hash reference giving a description, in different
languages, of the various CPAN chapter ids.

  foreach my $lang(sort keys %$chaps_desc) {
   print "For language $lang\n";
     foreach my $id(sort {$a <=> $b} keys %{$chaps_desc->{$lang}}) {
       print "   $id => $chaps_desc->{$lang}->{$id}\n";
     }
  }

Special characters used are HTML-encoded.

=item * C<$dslip>

This is a hash reference describing the I<dslip> (development,
support, language, interface, and public license) information,
available in different languages:

  for my $lang (sort keys %$dslip) {
    print "For language $lang:\n";
      for my $key (qw/d s l i p/) {
        print "  For key $key: $dslip->{$lang}->{$key}->{desc}\n";
          for my $entry (sort keys %{$dslip->{$lang}->{$key}}) {
            next if $entry eq 'desc';
            print "    Entry $entry: $dslip->{$lang}->{$key}->{$entry}\n"; 
        }
    }
  }

Special characters used are HTML-encoded.

=item * C<%na>

Translation of the phrase C<not known>.

=item * C<%langs>

This hash, whose keys are the keys of C<%na> and whose
values are C<1>, is a lookup hash to see what languages are available:

  for my $lang (keys %langs) {
    print "Language $lang is present\n";
  }

=item * C<$pages>

This hash, with keys being various languages, provides some
translations of terms used in the header and footer of the tt2 pages.

=item * C<$months>

This hash, with keys being various languages, provides
translations of the abbreviations of names of the months.

=back

=cut
