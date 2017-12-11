using System.Threading.Tasks;

namespace Appy.CommandQuery
{
    public interface IQuery<TReturnType, in TDataSource>
    {
        Task<TReturnType> Get(TDataSource dataSource);
    }
}