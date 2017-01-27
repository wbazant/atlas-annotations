function correspondingExpsFile() {
  file=$(basename $1)
  experiment=$(basename $(dirname $1))
  echo $ATLAS_EXPS/$experiment/$file
}

function compareProdToExps() {
  prodFile=$1
  expsFile=$(correspondingExpsFile $1)
  if [[ -e "$prodFile" && -e "$expsFile" ]] ; then
    cat <(wc -l $expsFile) <( wc -l $prodFile ) | tr '\n' ' ' | awk -F ' ' '{ if($3!=$1) {print $3-$1 "\t" $2 "\t" $4} }'
  fi

  if [[ ! -s "$prodFile" ]] ; then
     echo "Missing or empty prod file: " $prodFile
  fi

  if [[ ! -s "$expsFile" && -e "$(dirname $expsFile)" ]] ; then
    echo "Missing or empty exps file: " $expsFile
  fi
}

export -f compareProdToExps
export -f correspondingExpsFile

# the ^*^ is a placeholder
ls $ATLAS_PROD/analysis/*/*/experiments/*/*-analytics.tsv | xargs -n 1 bash -c 'compareProdToExps "$1"' ^*^
