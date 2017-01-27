
if [ $# -lt 2 ]; then
  echo "Usage: $0 old_rel new_rel"
  echo "e.g. $0 wbps_7 wbps_8"
  exit 1
fi

pushd $ATLAS_PROD/bioentity_properties/archive
find $1 -type f -name '*tsv' | xargs -n 1 wc -l | awk -F/ '{print $2 "\t" $1 "\t" $2}' | sort -k 1,1 > /var/tmp/ls-previous-$1
find $2 -type f -name '*tsv' | xargs -n 1 wc -l | awk -F/ '{print $2 "\t" $1 "\t" $2}' | sort -k 1,1 > /var/tmp/ls-current-$2
join -11 -21 /var/tmp/ls-previous-$1 /var/tmp/ls-current-$2 | awk '{print $5-$2 "\t" 2*($5-$2)/($5+$2+1) "\t" $1 "\t" $3 "\t" $2 "\t" $6 "\t" $5}' | sort -n > /var/tmp/ls-both-$1-$2
diff <(cut -d '\t' -f 1 /var/tmp/ls-previous-$1 ) <(cut -d '\t' -f 1 /var/tmp/ls-current-$2 ) > /var/tmp/ls-diff-$1-$2
popd
