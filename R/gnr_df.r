#' Wrapper function to apply gnr_simple across a data.frame or list of species
#' names
#'
#' Provides convienent output with a row per name. To streamline merging with
#' original data.
#'
#' @param df data.frame containing names to check
#' @param name.column integer or character string with column name containing
#' 		  species names
#' @param sourceid integer vector with data source ids.
#' see https://resolver.globalnames.org/sources/
#' @param best_match boolean. Should the best match be returned based on score?
#' @param canonical If TRUE, names do not include authorship or date
#' @param with_context If TRUE, Match scores are weighted for taxonomic
#' consistency
#' @param higher boolean: Return higher taxonomic classifications?
#'
#' @export gnr_df
#'
#' @return new data.frame original names (input_name), 1/0 flag for an exact
#' match,the best match (match_name, and other output from gnr_simple().
#' 			Will contain a row of NAs if no matches were found for a name.
#'
#' @examples
#' data(lakegeneva)
#' #example dataset with 50 rows
#'
#' lakegeneva<- genus_species_extract(lakegeneva,'phyto_name')
#' lakegeneva$genus_species <- trimws(paste(lakegeneva$genus,
#'	lakegeneva$species))
#'
#' #checking for matches from all GNRS sources:
#' lakegeneva.namematches <- gnr_df(lakegeneva,"genus_species")
#' lakegeneva.namematches


gnr_df<-function(df,name.column,higher=FALSE,sourceid=NULL,best_match=TRUE,canonical=TRUE,with_context=TRUE)
{
  #base API string
  gnrs.string<-"http://resolver.globalnames.org/name_resolvers.json?names="

  name<-df[,name.column]

  gnrs.name<-gsub(' ','+',name)
  if(length(gnrs.name)>1){
    gnrs.name<-paste(gnrs.name,collapse='|')
  }

  gnrs.string<-paste0(gnrs.string,gnrs.name)
  if(best_match){
    gnrs.string<-paste0(gnrs.string,"&best_match_only=true")
  }
  if(!is.null(sourceid)){
    data_sources<-paste(sourceid,collapse='|')
    gnrs.string<-paste0(gnrs.string,"&data_source_ids=",data_sources)
  }
  if(!with_context){
    gnrs.string<-paste0(gnrs.string,"&with_context=false")
  }
  con<-curl::curl(gnrs.string)

  results<-try(jsonlite::prettify(readLines(con,warn=FALSE)),silent=TRUE)
  if(is(results,"try-error"))
  {
    close(con)
    stop("No matches") #throw error
  }

  close(con)

  #transform to r list of lists
  result.list<-jsonlite::fromJSON(results)

  results.output.list<-result.list$data$results

  #results dataframe
  output<-data.frame(input_name=NULL,
                     match_name=NULL,
                     match_score=NULL,
                     match_type=NULL,
                     data_source=NULL,
                     data_import_date=NULL)
  for(i in 1:length(results.output.list)){
    if(is.null(result.list$data$results[[i]])){
      tmp<-data.frame(input_name=name[i],
                         match_name=NA,
                         match_score=NA,
                         match_type=NA,
                         data_source=NA,
                         data_import_date=NA
      )
      if(higher){
        tmp<-cbind(data.frame(Kingdom=NA,Phylum=NA,Class=NA,Order=NA,Family=NA),
                   tmp)
      }
      output<-rbind(output,tmp)
    }else{
      res.output<-data.frame(result.list$data$results[[i]])

    match.name<-if(canonical){
      res.output$canonical_form}else{res.output$name_string}

    tmp<-data.frame(input_name=name[i],
                    match_name=match.name,
                    match_score=res.output$score,
                    match_type=res.output$match_value,
                    data_source=res.output$data_source_title,
                    data_import_date=res.output$imported_at
    )

    if(higher){
      n<-nrow(res.output)
      higher.df<-data.frame(Kingdom=rep(NA,n),Phylum=rep(NA,n),Class=rep(NA,n),
                            Order=rep(NA,n),Family=rep(NA,n))
      higher.groups.keep<-tolower(names(higher.df))
      higher.taxonomy<-res.output$classification_path
      higher.taxonomy<-sapply(higher.taxonomy,strsplit,split='|',fixed=TRUE)
      higher.classes<-res.output$classification_path_ranks
      higher.classes<-sapply(higher.classes,strsplit,split='|',fixed=TRUE)
      for(i in 1:n){
        higher.df[i,]<-higher.taxonomy[[i]][match(higher.groups.keep,
                                                  tolower(higher.classes[[i]]))]
      }
      tmp<-cbind(higher.df,tmp)
    }
    output<-rbind(output,tmp)
  }

  }

  return(output)
}