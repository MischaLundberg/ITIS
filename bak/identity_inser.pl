#!/usr/bin/perl
use warnings; use strict;
use Seq;
use Bio::Seq;
my ($sam_file,$genome_file,$ins_len) = @ARGV;

#############

my %genomes = Seq::seq_hash($genome_file);
#print %simu_ge;
my $tnt_len = length ($genomes{tnt1});
##############################
   ## Scan sam file ##
print STDERR "scanning sam file.....\n";
open SAM, $sam_file or die $!;
my %reads;
my $num;
my $num_eff;
my $num_f;
while(<SAM>){
	chomp;
	my($id) = (split /\t/,$_)[0];
	if(! keys %reads or exists ($reads{$id})){
		$reads{$id} .= "############$_";
	}else{
		my @arr = values %reads;
		my @va = split '############',$arr[0];
		shift @va;
		find(@va);
		undef(%reads);
		$reads{$id} = "############$_";
	}
}



##################     parsing the paired reads


sub find{
	$num ++;
	my @reads = @_;
	my $rds = join "\n",@_;
	my %cors;
	foreach my $it (@reads){
		my($id,$flag,$chr,$pos,$cig,$nchr,$npos,$seq) = (split /\t/,$it)[0,1,2,3,5,6,7,9];	
		next if ($cig =~ /H/);
		(my $r = $flag ) =~ s/\w+(\d)/$1/;
		my $rc = (($flag =~ /r/)? -1:1);
		my $len = length $seq;
		my $c;
		my ($m);
		my $s = 0;
		while ($cig =~ /(\d+)([MS])/g){
			$m += $1 if ($2 eq "M");
			$s = $1 if ($2 eq "S" and $1 > $s);
		}
		if ($m/$len > 0.95 ){
			$c = "M";
		}elsif ( $cig =~ /^${s}S/ and $s >= 8){
			$c = "H:$s";
		}elsif ( $cig =~ /${s}S$/ and $s >=8 ){
			$c = "T:$s";
		}else{
			$c = "Z";
		}
		
		$cors{$r}{cig} = $c;
		$cors{$r}{direc} = $rc;
		$cors{$r}{chr} = $chr;
		$cors{$r}{id} = $id;
		$cors{$r}{pos} = $pos;  ### when reads if reverse complement the start loc of reads should plus the length of reads
		$cors{$r}{seq} = $seq;
	}

	my $chr1 = $cors{1}{chr};
	my $chr2 = $cors{2}{chr};	
	my $tnt;
	if ($chr1 =~ /tnt/){
		$tnt = 1;
	}elsif ( $chr2  =~ /tnt/){
		$tnt = 2;
	}else{
		$tnt = 0;
	}
	if ($chr1 ne $chr2  and $tnt > 0 ){  #### case : one reads on tnt and the other reads on genome
		my $tar = ($tnt ==1? 2:1);       #### which reads on genome ?
		
		#######*********** begain to analysis each possible case in alignment file ************#########
		if ($cors{$tnt}{cig} ne  "Z" and $cors{$tar}{cig} ne "Z"){   

			if ($cors{$tar}{cig} eq "M" and $cors{$tnt}{cig} eq "M"){   ## None  reads have clipped reads 
				if ( $cors{$tnt}{direc} == 1 and ( $cors{$tnt}{pos} > ($tnt_len - 610) or $cors{$tnt}{pos} < 510)){
					my ($ins_direc,$jun);
					if ($cors{$tar}{direc} == 1){
						$ins_direc = "R";
						$jun = $cors{$tar}{pos} + length($cors{$tar}{seq});
					}else{
						$ins_direc = "S";
						$jun = $cors{$tar}{pos};
					}
					print "$cors{$tnt}{id}\t$ins_direc\t$cors{$tar}{chr}\t$jun\tCT\n";
					print STDERR "$rds\n";
					$num_eff ++;
				}elsif ( $cors{$tnt}{direc} == -1 and ($cors{$tnt}{pos} <  510  or $cors{$tnt}{pos} > ($tnt_len - 610) )){
					my ($ins_direc,$jun);
					if ( $cors{$tar}{direc} == 1 ){
						$ins_direc = "S";
						$jun = $cors{$tar}{pos} + length($cors{$tar}{seq});
					}else{
						$ins_direc = "R";
						$jun = $cors{$tar}{pos};
					}
					print "$cors{$tnt}{id}\t$ins_direc\t$cors{$tar}{chr}\t$jun\tCH\n";
					print STDERR "$rds\n";
					$num_eff++;
				}else{
					$num_f ++;
				}
			}elsif($cors{$tar}{cig} eq "M" and $cors{$tnt}{cig} =~ /H:(\d+)/){
				my $l = $1;
				if ($cors{$tnt}{pos} <=2 or ($cors{$tnt}{pos} <= 4726 and $cors{$tnt}{pos} >4724)){
					my $que = substr($cors{$tnt}{seq},0,$l);
					( my $que_r = $que) =~ tr/ATCGatcg/TAGCtagc/;
					$que_r = reverse $que_r;
					my $ins_direc;
					my $sub;
					my $chr_t = $cors{$tar}{chr};
					my $pos_t = $cors{$tar}{pos};
					my $len_t = length $cors{$tar}{seq};
					if($cors{$tar}{direc} == 1){
						$ins_direc = "S";
						$sub = substr($genomes{$chr_t},$pos_t-1,$ins_len);
						my $jun = -1;
						my $m_r = 2 ;
						for my $i (0..(length ($sub)- length ($que))){
							my $s = substr($sub,$i,$l);
							my $diffcount = () = ($que ^ $s) =~ /[^\x00]/g;
							if ($diffcount < $m_r){
								$jun = $i;
								$m_r = $diffcount;
							}
						}
						if($jun != -1){
							$jun = $jun + $pos_t;
							print "$cors{$tnt}{id}\t$ins_direc\t$chr_t\t$jun\tTH\n";
							print STDERR "$rds\n";
						}else{
							$num_f ++;
						}
					}else{
						$ins_direc = "R";
						my $sub_start = $pos_t+$len_t-$ins_len;
						$sub = substr($genomes{$chr_t},$sub_start-1,$ins_len);
						my $jun = -1;
						my $m_r = 2;
						for my $i (0..(length ($sub)- length ($que))){
							my $s = substr($sub,$i,$l);
							my $diffcount = () = ($que_r ^ $s) =~ /[^\x00]/g;
							if ($diffcount < $m_r){
								$jun = $i;
								$m_r = $diffcount;
							}
						}
						if($jun != -1){
							$jun = $jun + $sub_start;
							print "$cors{$tnt}{id}\t$ins_direc\t$chr_t\t$jun\tTH\n";
							print STDERR "$rds\n";
						}else{
							$num_f++;
						}
					}
				}else{
					$num_f ++;
				}
			}elsif ( $cors{$tar}{cig} eq "M" and $cors{$tnt}{cig} =~ /T:(\d+)/ ){
				my $l = $1;
				my $end_pos = $cors{$tnt}{pos} + length($cors{$tnt}{seq}) - $l;
				if ($end_pos >= $tnt_len-1 or 	($end_pos <= 612 and $end_pos >= 608)){
					my $que = substr($cors{$tnt}{seq},-$l);
					( my $que_r = $que) =~ tr/ATCGatcg/TAGCtagc/;
					$que_r = reverse $que_r;
					my $ins_direc;
					my $sub;
					my $chr_t = $cors{$tar}{chr};
					my $pos_t = $cors{$tar}{pos};
					my $len_t = length $cors{$tar}{seq};

					if($cors{$tar}{direc} == 1){
						$ins_direc = "R";
						$sub = substr($genomes{$chr_t},$pos_t-1,$ins_len);
						my $jun = -1;
						my $m_r = 2 ;
						for my $i (0..(length ($sub)- length ($que))){
							my $s = substr($sub,$i,$l);
							my $diffcount = () = ($que ^ $s) =~ /[^\x00]/g;
							if ($diffcount <= $m_r){
								$jun = $i;
								$m_r = $diffcount;
							}
						}
						if($jun != -1){
							$jun = $jun + $pos_t;
							print "$cors{$tnt}{id}\t$ins_direc\t$chr_t\t$jun\tTT\n";
							print STDERR "$rds\n";
						}else{
							$num_f ++;
						}
					}else{
						$ins_direc = "S";
						my $sub_start = $pos_t+$len_t-$ins_len;
						$sub = substr($genomes{$chr_t},$pos_t-1,$ins_len);
						my $jun = -1;
						my $m_r = 2 ;
						for my $i (0..(length ($sub)- length ($que))){
							my $s = substr($sub,$i,$l);
							my $diffcount = () = ($que ^ $s) =~ /[^\x00]/g;
							if ($diffcount <= $m_r){
								$jun = $i;
								$m_r = $diffcount;
							}
						}
						if($jun != -1){
							$jun = $jun + $pos_t;
							print "$cors{$tnt}{id}\t$ins_direc\t$chr_t\t$jun\tTT\n";
							print STDERR "$rds\n";
						}else{
							$num_f ++;
						}
					}
				}
			}elsif($cors{$tar}{cig} =~ /H:(\d+)/){
				my $l = $1;
				my $que = substr($cors{$tar}{seq},0,$l);
				( my $que_r = $que) =~ tr/ATCGatcg/TAGCtagc/;
				$que_r = reverse $que_r; 
				my $len = (length $que ) ;
				my $sub_h = substr($genomes{tnt1},0,$len);
				my $sub_t = substr($genomes{tnt1},-$len);
				my $ma = match($que,$que_r,$sub_h,$sub_t);
				if ($ma != 0){
					my $ma_direc = $ma * $cors{$tar}{direc};
					if (($ma_direc == -3 and $cors{$tnt}{direc} == 1)){
						my $ins_direc = "S";
						my $jun  = $cors{$tar}{pos};
				
						print "$cors{$tar}{id}\t$ins_direc\t$cors{$tar}{chr}\t$jun\tGT\n";
						print STDERR "$rds\n";
						$num_eff++;
					}elsif(( $ma_direc == 2 and $cors{$tnt}{direc} == -1)) {
						my $ins_direc = "R";
						my $jun = $cors{$tar}{pos};
						print "$cors{$tar}{id}\t$ins_direc\t$cors{$tar}{chr}\t$jun\tGH\n";
						print STDERR "$rds\n";
						$num_eff++;
					}else{
						$num_f ++;
					}
				}else{
					$num_f ++;
				}
			}elsif($cors{$tar}{cig} =~ /T:(\d+)/){
				my $l = $1;
				my $que = substr($cors{$tar}{seq},-$l);
				( my $que_r = $que) =~ tr/ATCGatcg/TAGCtagc/;
				$que_r = reverse $que_r; 
				my $len = (length $que ) ;
				my $sub_h = substr($genomes{tnt1},0,$len);
				my $sub_t = substr($genomes{tnt1},-$len);
				my $ma = match($que,$que_r,$sub_h,$sub_t);
				if ($ma != 0){
					my $ma_direc = $ma * $cors{$tar}{direc};
					if (($ma_direc == -3 and $cors{$tnt}{direc} == 1)){
						my $ins_direc = "R";
						my $jun = $cors{$tar}{pos} + length($cors{$tar}{seq})-$l;
						print "$cors{$tar}{id}\t$ins_direc\t$cors{$tar}{chr}\t$jun\tGT\n";
						print STDERR "$rds\n";
						$num_eff++;
					}elsif ( $ma_direc == 2 and $cors{$tnt}{direc} == -1){
						my $ins_direc = "S";
						my $jun = $cors{$tar}{pos} + length($cors{$tar}{seq})-$l;
						print "$cors{$tar}{id}\t$ins_direc\t$cors{$tar}{chr}\t$jun\tGH\n";
						print STDERR "$rds\n";
						$num_eff++;
					}else{
						$num_f++;
					}
				}else{
					$num_f++;
				}
			}else{
				$num++;
			}
		}
	}
}

sub match {
	my %relas;
	for my $j (0..1){
		for my $k (2..3){
			my $que = $_[$j];
			my $sub = $_[$k];
			my $diffcount = () = ($que ^ $sub) =~ /[^\x00]/g;
			#print "$diffcount\t$len_q\n";
			my $direc = ($j==0?1:-1);
			$relas{$diffcount} = $direc*$k;
		}
	}
	foreach (sort {$a<=>$b} keys %relas){
		if ( $_ <= 1){
			my $v = $relas{$_};
			return "$v";   #### return value SH  ST RH  RT  
		}else{
			return "0";
		}
		last;
	}
}

