package CPAN::Search::Lite::Lang;
use strict;
use warnings;

use base qw(Exporter);
our (@EXPORT_OK, %na, $chaps_desc, %langs, $pages, $dslip);
@EXPORT_OK = qw(%na $chaps_desc %langs $pages $dslip);

%na = (
       de => 'nicht spezifiziert',
       fr => 'non indiqu&eacute;',
       en => 'not specified',
       es => 'no especificado',
       it => 'non specificato',
      );

make_langs();

$chaps_desc = {
    de => {
        2 => q{Perl Kern-Module},
        3 => q{Entwicklung Unterst&uuml;tzung},
        4 => q{Betriebssystem-Schnittstellen},
        5 => q{Netzwerkanschlu&szlig;-Vorrichtungen Ipc},
        6 => q{Daten-Art Dienstprogramme},
        7 => q{Datenbankschnittstellen},
        8 => q{Benutzerschnittstellen},
        9 => q{Sprachenschnittstellen},
        10 => q{Akte Nennt Die Systeme Blockierung},
        11 => q{Zeichenkette Lang Text Proc},
        12 => q{Optativ Arg Param Proc},
        13 => q{Internationalisierung Schauplatz},
        14 => q{Sicherheit und Verschl&uuml;sselung},
        15 => q{World Wide Web HTML HTTP Cgi},
        16 => q{Bediener-und D&auml;mon-Dienstprogramme},
        17 => q{Archivieren und Kompression},
        18 => q{Bilder Pixmaps Bit&uuml;bersichten},
        19 => q{Post-und USENET-Nachrichten},
        20 => q{Steuern Sie Fluss-Dienstprogramme},
        21 => q{Ordnen Sie Handgriff-Eingang Ausgang Ein},
        22 => q{Microsoft Windows Module},
        23 => q{Verschiedene Module},
        24 => q{Kommerzielle Programmschnittstellen},
        99 => q{Nicht Schon In Modulelist},
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
        2 => q{M&oacute;dulos De la Base Del Perl},
        3 => q{Ayuda Del Desarrollo},
        4 => q{Interfaces Del Sistema Operativo},
        5 => q{Dispositivos Ipc Del Establecimiento de una red},
        6 => q{Tipo De Datos Utilidades},
        7 => q{Interfaces De Base de datos},
        8 => q{Interfaces utilizador},
        9 => q{Interfaces De la Lengua},
        10 => q{El Archivo Nombra La Fijaci&oacute;n De los Sistemas},
        11 => q{Texto Proc De Lang De la Secuencia},
        12 => q{Param Proc Del OPT Arg},
        13 => q{Locale De la Internacionalizaci&oacute;n},
        14 => q{Seguridad y cifrado},
        15 => q{Cgi Mundial del HTTP del HTML Del Web},
        16 => q{Utilidades del servidor y del demonio},
        17 => q{El archivar y compresi&oacute;n},
        18 => q{BITMAP De Pixmaps De las Im&aacute;genes},
        19 => q{Noticias del correo y de USENET},
        20 => q{Controle Las Utilidades Del Flujo},
        21 => q{Archive La Salida De la Entrada De la Manija},
        22 => q{M&oacute;dulos de Microsoft Windows},
        23 => q{M&oacute;dulos Miscel&aacute;neos},
        24 => q{Interfaces De Software Comerciales},
        99 => q{No todav&iacute;a En Modulelist},
    },
    fr => {
        2 => q{Modules De Noyau De Perl},
        3 => q{Appui De D&eacute;veloppement},
        4 => q{Interfaces De Logiciel},
        5 => q{Dispositifs IPC De Gestion de r&eacute;seau},
        6 => q{Type De Donn&eacute;es Utilit&eacute;s},
        7 => q{Interfaces De Base de donn&eacute;es},
        8 => q{Interfaces utilisateur},
        9 => q{Interfaces De Langue},
        10 => q{Le Dossier Appelle La Fermeture De Syst&egrave;mes},
        11 => q{Texte Proc De Lang De Corde},
        12 => q{Param Proc D'OPT Arg},
        13 => q{Lieu D'Internationalisation},
        14 => q{S&eacute;curit&eacute; et chiffrage},
        15 => q{Cgi de HTTP de HTML Mondial De Web},
        16 => q{Utilit&eacute;s de serveur et de d&eacute;mon},
        17 => q{Archivage et compression},
        18 => q{Cartes binaires De Pixmaps D'Images},
        19 => q{Courrier et nouvelles Usenet},
        20 => q{Commandez Les Utilit&eacute;s D'&Eacute;coulement},
        21 => q{Classez Le Rendement D'Entr&eacute;e De Poign&eacute;e},
        22 => q{Modules de Microsoft Windows},
        23 => q{Modules Divers},
        24 => q{Interfaces De Logiciel Commerciales},
        99 => q{Pas encore Dans Modulelist},
    },
    it => {
        2 => q{Moduli Di Nucleo Del Perl},
        3 => q{Supporto Di Sviluppo},
        4 => q{Interfacce Del Sistema Operativo},
        5 => q{Dispositivi Ipc Della Rete},
        6 => q{Tipo di dati Programmi di utilit&agrave;},
        7 => q{Interfacce Di Base di dati},
        8 => q{Interfacce Di Utente},
        9 => q{Interfacce Di Lingua},
        10 => q{La Lima Chiama Il Bloccaggio Dei Sistemi},
        11 => q{Testo Proc Di Lang Della Stringa},
        12 => q{Param Proc Dell'OPT Arg},
        13 => q{Locale Di Internazionalizzazione},
        14 => q{Sicurezza e crittografia},
        15 => q{Cgi del HTTP del HTML Di World Wide Web},
        16 => q{Programmi di utilit&agrave; del daemon e dell'assistente},
        17 => q{Archiviatura e compressione},
        18 => q{Indirizzamenti a bit Di Pixmaps Di Immagini},
        19 => q{Notizie di USENET e della posta},
        20 => q{Controlli I Programmi di utilit&agrave; Di Flusso},
        21 => q{Archivi L'Uscita Dell'Input Della Maniglia},
        22 => q{Moduli Di Microsoft Windows},
        23 => q{Moduli Vari},
        24 => q{Interfacce Di Software Commerciali},
        99 => q{Non ancora In Modulelist},
    },
};

$dslip = {
  de => {
    d => {
      M => q{Reifen Sie (keine rigorose Definition)},
      R => q{Freigegeben},
      S => q{Standard, geliefert mit Perl 5},
      a => q{Alphapr&uuml;fung},
      b => q{Betapr&uuml;fung},
      c => q{Im Bau aber Voralpha (nicht schon freigegeben)},
      desc => q{Entwicklung Stadium (Anmerkung: * KEINE IMPLIZIERTEN SYNCHRONISIERZEITMARKEN *)},
      i => q{Idee, verzeichnet, um &Uuml;bereinstimmung oder als placeholder zu gewinnen},
    },
    s => {
      a => q{Verlassen, ist das Modul von seinem Autor verlassen worden},
      d => q{Entwickler},
      desc => q{St&uuml;tzungslinie},
      m => q{Verschicken-Liste},
      n => q{Kein bekannt, Versuch comp.lang.perl.modules},
      u => q{USENET-NEWSGROUP comp.lang.perl.modules},
    },
    l => {
      '+' => q{C++ und Perl, ein C++ Compiler sind erforderlich},
      c => q{C und Perl, ein C Compiler sind erforderlich},
      desc => q{Sprache Verwendete},
      h => q{Der Mischling, geschrieben in Perl mit wahlweise freigestelltem C Code, kein Compiler ben&ouml;tigte},
      o => q{Perl und eine andere Sprache anders als C oder C++},
      p => q{Perl-nur, kein ben&ouml;tigter Compiler, sollte Plattformunabh&auml;ngiges sein},
    },
    i => {
      O => q{Gegenstand orientierte sich mit gesegneten Hinweisen und/oder Erbschaft},
      desc => q{Schnittstelle Art},
      f => q{normale Funktionen, keine Hinweise verwendeten},
      h => q{Mischling-, Gegenstand- und Funktionsschnittstellen vorhanden},
      n => q{keine Schnittstelle an allen (huh?)},
      r => q{etwas Gebrauch unblessed Hinweise oder Riegel},
    },
    p => {
      a => q{K&uuml;nstlerische Lizenz alleine},
      b => q{BSD: Die BSD Lizenz},
      desc => q{Allgemeine Lizenz},
      g => q{Gpl: Gnu &Ouml;ffentlichkeit Lizenz},
      l => q{LGPL: "GNU wenig &Ouml;ffentlichkeit Lizenz" (vorher bekannt als "GNU Bibliothek-&Ouml;ffentlichkeit Lizenz")},
      o => q{anderes (aber Verteilung erlaubt ohne Beschr&auml;nkungen)},
      p => q{Standard-Perl: Benutzer kann zwischen GPL w&auml;hlen und k&uuml;nstlerisch},
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
      M => q{Mad&uacute;rese (ninguna definici&oacute;n rigurosa)},
      R => q{Lanzado},
      S => q{Est&aacute;ndar, provisto de Perl 5},
      a => q{Prueba de la alfa},
      b => q{Prueba beta},
      c => q{Bajo la construcci&oacute;n pero pre-alfa (no todav&iacute;a lanzadas)},
      desc => q{Etapa Del Desarrollo (Nota: * NINGUNOS CALENDARIOS IMPLICADOS *)},
      i => q{Idea, enumerada para ganar consenso o como placeholder},
    },
    s => {
      a => q{Abandonado, el m&oacute;dulo ha sido abandonado por su autor},
      d => q{Revelador},
      desc => q{Nivel De Ayuda},
      m => q{Enviar-lista},
      n => q{Ninguno sabida, intento comp.lang.perl.modules},
      u => q{Newsgroup de USENET comp.lang.perl.modules},
    },
    l => {
      '+' => q{C++ y el Perl, un recopilador de C++ ser&aacute;n necesarios},
      c => q{C y el Perl, un recopilador de C ser&aacute;n necesarios},
      desc => q{La Lengua Utiliz&oacute;},
      h => q{El h&iacute;brido, escrito en el Perl con c&oacute;digo opcional de C, ning&uacute;n},
      o => q{Perl y otra lengua con excepci&oacute;n de C o de C++},
      p => q{Perl-solamente, ning&uacute;n recopilador necesitado, debe ser independent de la plataforma},
    },
    i => {
      O => q{El objeto orient&oacute; con referencias bendecidas y/o herencia},
      desc => q{Estilo Del Interfaz},
      f => q{las funciones llanas, ningunas referencias utilizaron},
      h => q{interfaces del h&iacute;brido, del objeto y de la funci&oacute;n disponibles},
      n => q{ning&uacute;n interfaz en todos (huh?)},
      r => q{un cierto uso de unblessed referencias o lazos},
    },
    p => {
      a => q{Licencia art&iacute;stica solamente},
      b => q{BSD: La Licencia del BSD},
      desc => q{Licencia P&uacute;blica},
      g => q{GLP: Licencia El P&uacute;blico en general del GnuG},
      l => q{LGPL: "GNU poca licencia el p&uacute;blico en general" (conocida previamente como "licencia el p&uacute;blico en general de la biblioteca del GNU")},
      o => q{otro (solamente distribuci&oacute;n permitida sin restricciones)},
      p => q{Esta'ndar-Perl: el usuario puede elegir entre el GLP y art&iacute;stico},
    },
  },
  fr => {
    d => {
      M => q{M&ucirc;rissez (aucune d&eacute;finition rigoureuse)},
      R => q{Lib&eacute;r&eacute;},
      S => q{Norme, fournie avec Perl 5},
      a => q{Essai d'alpha},
      b => q{B&ecirc;ta essai},
      c => q{En construction mais l'pr&eacute;-alpha (pas encore lib&eacute;r&eacute;s)},
      desc => q{&Eacute;tape De D&eacute;veloppement (Note : * AUCUNS CALENDRIERS IMPLICITES *)},
      i => q{Id&eacute;e, &eacute;num&eacute;r&eacute;e pour gagner le consensus ou comme placeholder},
    },
    s => {
      a => q{Abandonn&eacute;, le module a &eacute;t&eacute; abandonn&eacute; par son auteur},
      d => q{R&eacute;alisateur},
      desc => q{Niveau De Soutien},
      m => q{Exp&eacute;dier-liste},
      n => q{Aucun connu, essai comp.lang.perl.modules},
      u => q{Groupe de discussion Usenet comp.lang.perl.modules},
    },
    l => {
      '+' => q{C++ et Perl, un compilateur de C++ seront n&eacute;cessaires},
      c => q{C et Perl, un compilateur de C seront n&eacute;cessaires},
      desc => q{La Langue A employ&eacute;},
      h => q{L'hybride, &eacute;crit dans le Perl avec le code facultatif de C, aucun compilateur a eu besoin},
      o => q{un Perl et une langue diff&eacute;rente autre que C ou C++},
      p => q{Perl-seulement, aucun compilateur requis, devrait &ecirc;tre ind&eacute;pendant de plateforme},
    },
    i => {
      O => q{L'objet a orient&eacute; en utilisant des r&eacute;f&eacute;rences b&eacute;nies et/ou la transmission},
      desc => q{Mod&egrave;le D'Interface},
      f => q{les fonctions plates, aucunes r&eacute;f&eacute;rences ont employ&eacute;},
      h => q{interfaces d'hybride, d'objet et de fonction disponibles},
      n => q{aucune interface du tout (huh ?)},
      r => q{une certaine utilisation de unblessed des r&eacute;f&eacute;rences ou des cravates},
    },
    p => {
      a => q{Seul permis artistique},
      b => q{BSD : Le Permis de BSD},
      desc => q{Permis Public},
      g => q{GPL : Permis De Grand Public de Gnu},
      l => q{LGPL : "GNU peu de permis de grand public" (pr&eacute;c&eacute;demment connusous le nom de "permis de grand public de biblioth&egrave;que de GNU")},
      o => q{autre (mais distribution permise sans restrictions)},
      p => q{Standard-Perl : l'utilisateur peut choisir entre le GPL et artistique},
    },
  },
  it => {
    d => {
      M => q{Faccia maturare (nessuna definizione rigorosa)},
      R => q{Liberato},
      S => q{Campione, fornito con il Perl 5},
      a => q{Prova dell'alfa},
      b => q{Beta prova},
      c => q{In costruzione ma l'pre-alfa (non ancora liberati)},
      desc => q{Fase Di Sviluppo (Nota: * NESSUN SCALE CRONOLOGICHE IMPLICITE *)},
      i => q{Idea, elencata per guadagnare consenso o come placeholder},
    },
    s => {
      a => q{Abbandonato, il modulo &egrave; stato abbandonato dal relativo autore},
      d => q{Sviluppatore},
      desc => q{Livello Di Sostegno},
      m => q{Sped-lista},
      n => q{Nessuno conosciuti, prova comp.lang.perl.modules},
      u => q{Newsgroup di USENET comp.lang.perl.modules},
    },
    l => {
      '+' => q{C++ ed il Perl, un compilatore di C++ saranno necessari},
      c => q{La C ed il Perl, un compilatore di C saranno necessari},
      desc => q{Lingua Usata},
      h => q{L'ibrido, scritto in Perl con il codice facoltativo di C, nessun compilatore ha avuto bisogno di},
      o => q{Perl e un'altra lingua tranne la C o C++},
      p => q{Perl-soltanto, nessun compilatore stato necessario, dovrebbe essere independent della piattaforma},
    },
    i => {
      O => q{L'oggetto ha orientato usando i riferimenti benedetti e/o l'eredit&agrave;},
      desc => q{Stile Dell'Interfaccia},
      f => q{funzioni normali, nessun riferimenti usati},
      h => q{interfacce dell'ibrido, dell'oggetto e di funzione disponibili},
      n => q{nessun'interfaccia affatto (huh?)},
      r => q{un certo uso di unblessed i riferimenti o i legami},
    },
    p => {
      a => q{Autorizzazione artistica da solo},
      b => q{BSD: L'Autorizzazione del BSD},
      desc => q{Autorizzazione Pubblica},
      g => q{Gpl: Autorizzazione Del Grande Pubblico di Gnu},
      l => q{LGPL: "GNU poca autorizzazione del grande pubblico" (precedentemente conosciuta come "l'autorizzazione del grande pubblico della biblioteca di GNU")},
      o => q{altro (ma distribuzione permessa senza limitazioni)},
      p => q{Standard-Perl: l'utente pu&ograve; scegliere fra GPL ed artistico},
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
  fr => {  title => 'Passez en revue et recherchez CPAN',
           list => { module => 'Modules',
                    dist => 'Distributions',
                    author => 'Auteurs',
                  },
          buttons => {Home => 'Home',
                      Documentation => 'Documentation',
                      Recent => 'R&eacute;cent',
                      Mirror => 'Miroir',
                      Modules => 'Modules',
                      Distributions => 'Distributions',
                      Authors => 'Auteurs',
                  },
           form => {Find => 'Trouvaille',
                    in => 'dans',
                    Search => 'Recherche',
                   },
           Problems => 'Probl&egrave;mes, suggestions, ou commentaires &agrave;',
           Questions => 'Questions? V&eacute;rifiez le',
      },
 de => {  title => 'Grasen Sie und suchen Sie CPAN',
           list => { module => 'Module',
                    dist => 'Verteilungen',
                    author => 'Autoren',
                  },
          buttons => {Home => 'Home',
                      Documentation => 'Unterlagen',
                      Recent => 'Neu',
                      Mirror => 'Spiegel',
                      Modules => 'Module',
                      Distributions => 'Verteilungen',
                      Authors => 'Autoren',
                  },
           form => {Find => 'Entdeckung',
                    in => 'dans',
                    Search => 'Suche',
                   },
           Problems => 'Probleme, Vorschl&auml;ge oder Anmerkungen zu',
           Questions => 'Fragen? &Uuml;berpr&uuml;fen Sie das',
      },
 it => {  title => 'Passi in rassegna e cerchi CPAN',
           list => { module => 'Moduli',
                    dist => 'Distribuzioni',
                    author => 'Autori',
                  },
          buttons => {Home => 'Home',
                      Documentation => 'Documentazione',
                      Recent => 'Recente',
                      Mirror => 'Specchio',
                      Modules => 'Moduli',
                      Distributions => 'Distribuzioni',
                      Authors => 'Autori',
                  },
           form => {Find => 'Ritrovamento',
                    in => 'dans',
                    Search => 'Ricerca',
                   },
           Problems => 'Problemi, suggerimenti, o osservazioni a',
           Questions => 'Domande? Controlli il',
      },
  es => {  title => 'Hojee y busque CPAN',
           list => { module => 'M&oacute;dulos',
                    dist => 'Distribuciones',
                    author => 'Autores',
                  },
          buttons => {Home => 'Home',
                      Documentation => 'Documentaci&oacute;n',
                      Recent => 'Reciente',
                      Mirror => 'Espejo',
                      Modules => 'M&oacute;dulos',
                      Distributions => 'Distribuciones',
                      Authors => 'Autores',
                  },
           form => {Find => 'Hallazgo',
                    in => 'en',
                    Search => 'B&uacute;squeda',
                   },
           Problems => 'Problemas, sugerencias, o comentarios a',
           Questions => '&iquest;Preguntas? Compruebe el',
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

=back

=cut
